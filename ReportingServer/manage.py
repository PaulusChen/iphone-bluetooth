#!/usr/bin/env python
#
# Copyright 2007 Google Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

import cgi

from google.appengine.ext import webapp
from google.appengine.ext import db
from google.appengine.ext import blobstore
from google.appengine.ext.webapp import blobstore_handlers
from google.appengine.ext.webapp import util

import logging
import plistlib
from  StringIO import StringIO

import zipfile

from service import ReportModel


class ZippedLogHandler(webapp.RequestHandler):
    def get(self):
        id = self.request.get('id', None)
        
        test = self.request.get('test', None)

        report = ReportModel.get_by_id(int(id))

        # create the zip stream
        zipstream = StringIO()
        file = zipfile.ZipFile(zipstream, "w")
        file.filename = str('log-id%s-%s.zip' % (id, report.date.strftime('%Y-%m-%d %H-%M-%S')))

        for blobKey in report.blobKeys:
            meta = blobstore.BlobInfo.get(blobKey)
            data = blobstore.BlobReader(blobKey).read()
            if test:
                self.response.out.write('<b>%s</b><br/>' % meta.filename)
            else:
                file.writestr(str(meta.filename), data)

        if test:
            return

        # we have finished with the zip so package it up and write the directory
        file.close()
        zipstream.seek(0)

        # create and return the output stream
        self.response.headers['Content-Type'] ='application/zip'
        self.response.headers['Content-Disposition'] = 'attachment; filename="%s"' % file.filename
        while True:
            buf = zipstream.read(10240)
            if buf == "": break
            self.response.out.write(buf)
       

class ItemInfoHandler(webapp.RequestHandler):
    def get(self):
        self.response.out.write('<html>')
        self.response.out.write('<head><link rel=StyleSheet HREF="/styles/manage.css" TYPE="text/css"></head>')
        self.response.out.write('<body>')
        id = self.request.get('id', None)
        
        report = ReportModel.get_by_id(int(id))
        
        self.response.out.write('<h3>%s</h3>' % cgi.escape(str(report.date)))

        reportMetaBlobData = blobstore.BlobReader(report.userProps).read()

        reportMetaPlist = plistlib.readPlistFromString(reportMetaBlobData)

        self.response.out.write('Repro steps: <pre>%s</pre>' % cgi.escape(reportMetaPlist['ReproSteps']))

        self.response.out.write('<a href="getlogs?id=%s">Download logs</a>' % id)
        
        self.response.out.write('</body></html>')
        

class ListHandler(webapp.RequestHandler):
    def get(self):
        self.response.out.write('<html>')
        
        self.response.out.write('<head>')
        self.response.out.write('<link rel=StyleSheet HREF="/styles/manage.css" TYPE="text/css">')
        self.response.out.write("""<script>
function showItem(id) {
    window.location = "view?id=" + id;
}
</script>""")
        self.response.out.write('</head>')
        
        self.response.out.write('<body>')

        reports = db.GqlQuery("SELECT * FROM ReportModel ORDER BY date DESC LIMIT 10")
        
        self.response.out.write('<table>')

        self.response.out.write('<tr>')
        columns = ["Date", "UDID", "db ID"]
        for colName in columns:
            self.response.out.write('<th>%s</th>' % colName)
        self.response.out.write('</tr>')

        for report in reports:
            id = cgi.escape(str(report.key().id()))
            self.response.out.write("<tr onclick='showItem(""%s"")'><td>%s</td><td>%s</td><td>%s</td></tr>"  % (id, cgi.escape(str(report.date)), cgi.escape(str(report.udid)), id))
            
        self.response.out.write('</table>')

        self.response.out.write('</body></html>')
        

application = webapp.WSGIApplication([('/manage/list', ListHandler),
                                      ('/manage/view', ItemInfoHandler),
                                      ('/manage/getlogs', ZippedLogHandler),
                                      ],
                                         debug=True)

def main():
    util.run_wsgi_app(application)


if __name__ == '__main__':
    main()
