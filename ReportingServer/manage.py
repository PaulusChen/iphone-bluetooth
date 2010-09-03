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

import os
import cgi
import datetime

from google.appengine.ext import webapp
from google.appengine.ext import db
from google.appengine.ext import blobstore
from google.appengine.ext.webapp import blobstore_handlers
from google.appengine.ext.webapp import util
from google.appengine.ext.webapp import template

import logging
import plistlib
from StringIO import StringIO

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
        id = self.request.get('id', None)       
        report = ReportModel.get_by_id(int(id))
        
        reproSteps = None
        reporterVersion = None
        if report.userProps:
            reportMetaBlobData = blobstore.BlobReader(report.userProps).read()

            reportMetaPlist = plistlib.readPlistFromString(reportMetaBlobData)
            reproSteps = reportMetaPlist.get('ReproSteps', None)
            reporterVersion = reportMetaPlist.get('ReporterVersion', None)

        template_values = {
            'id': id,
            'header': "Report %u (%s)" % (int(id), report.date.strftime('%Y-%m-%d %H:%M:%S')),
            'repro': reproSteps,
            'reporterVersion': reporterVersion,
            'comment': report.comment,
            }

        path = os.path.join(os.path.dirname(__file__), 'templates', 'manage_view.html')
        self.response.out.write(template.render(path, template_values))
        
    def post(self):
        comment = self.request.get('comment', None)

        id = self.request.get('id', None)
        report = ReportModel.get_by_id(int(id))

        report.comment = comment
        report.put()
        
        self.redirect('view?id=%u' % report.key().id())

class Row:
    def __init__(self):
        return
    
class ListHandler(webapp.RequestHandler):
    def get(self):
        offset = int(self.request.get('offset', '0'))
        pagesize = 10

        query = db.Query(ReportModel)

        query.order('-date')
        
        reports = query.fetch(pagesize, offset)
                
        columnHeaders = ["ID", "Time", "UDID", "Comment"]

        todayOrd = datetime.date.today().toordinal()

        reportRows = []
        lastHeader = None
        for report in reports:
            id = report.key().id()
            ord = report.date.date().toordinal()
            
            if ord == todayOrd:
                header = "Today"
            elif ord == todayOrd - 1:
                header = "Yesterday"
            else:
                header = "%u days ago" % (todayOrd - ord)
            if header != lastHeader:
                lastHeader = header
                headerRow = Row()

                headerRow.header = header
                reportRows.append(headerRow)
            row = Row()
            row.id = id
            row.columnValues = [id, report.date.strftime('%H:%M:%S'), str(report.udid), report.comment]
            reportRows.append(row)         


        prevOffset = offset - pagesize
        if prevOffset < 0:
            prevOffset = 0
        if prevOffset == offset:
            prevOffset = None
        nextOffset = None
        if len(reports) == pagesize:
            nextOffset = offset + pagesize      

        template_values = {
            'columnHeaders': columnHeaders,
            'reports': reportRows,
            'prevOffset': prevOffset,
            'nextOffset': nextOffset,
            }
        path = os.path.join(os.path.dirname(__file__), 'templates', 'manage_list.html')
        self.response.out.write(template.render(path, template_values))

       

application = webapp.WSGIApplication([('/manage/list', ListHandler),
                                      ('/manage/view', ItemInfoHandler),
                                      ('/manage/getlogs', ZippedLogHandler),
                                      ],
                                         debug=True)

def main():
    util.run_wsgi_app(application)


if __name__ == '__main__':
    main()
