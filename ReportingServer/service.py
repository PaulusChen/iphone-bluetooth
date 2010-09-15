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
from google.appengine.ext import webapp
from google.appengine.ext import db
from google.appengine.ext import blobstore
from google.appengine.ext.webapp import blobstore_handlers
from google.appengine.ext.webapp import util
from google.appengine.api import mail

import logging
import plistlib
import urlparse
import urllib

class ReportModel(db.Model): 
    blobKeys = db.StringListProperty()
    userProps = blobstore.BlobReferenceProperty()
    udid = db.StringProperty(multiline=False)
    date = db.DateTimeProperty(auto_now_add=True)
    comment = db.StringProperty(multiline=True)

def getBaseUrl(requestHandler, secure=None):
    scheme, host, path, parameters, query, fragment = urlparse.urlparse(requestHandler.request.url)
    if secure:
        scheme = 'https'
    return "%s://%s" % (scheme, host)

def getUploadUrl(requestHandler):
    udid = requestHandler.request.headers.get("Udid", None)
    qp = {}
    if udid:
        qp['udid'] = udid
    if requestHandler.request.scheme == 'https':
        qp['s'] = 1
    qs = urllib.urlencode(qp)
    upload_redir_url = '%s/up' % getBaseUrl(requestHandler)
    if len(qs) != 0:
        upload_redir_url += '?' + qs
    return blobstore.create_upload_url(upload_redir_url)
    
class ReportHandler(webapp.RequestHandler):
    def get(self):
        self.redirect(getUploadUrl(self))

class ResponseHandler(webapp.RequestHandler):
    def get(self):
        id = self.request.get('id', None)
        if not id:
            return
        responseDict = { 'reportId': id,
            }
        self.response.headers['Content-Type'] = 'application/xml'
        self.response.out.write(plistlib.writePlistToString(responseDict))

class UploadHandler(blobstore_handlers.BlobstoreUploadHandler): 
    def post(self):
        udid = self.request.get('udid', None)
        blobKeys = []
        userProps = None
        for upload in self.get_uploads('file'):
            blobKeys.append(str(upload.key()))
            if not userProps and upload.filename == "ReportMetadata.plist":
                userProps = upload
         
        report = ReportModel(blobKeys = blobKeys, userProps = userProps, udid = udid)
        db.put(report)

        self.sendMailForReport(report)
        self.redirect('%s/response?id=%u' % (self.baseUrl(), report.key().id()))

    def get(self):
        self.redirect(self.baseUrl())

    def baseUrl(self):
        return getBaseUrl(self, self.request.get('s', None))
    
    def sendMailForReport(self, report):
        reportText = "<Empty>"
        if report.userProps:
            reportMetaBlobData = blobstore.BlobReader(report.userProps).read()
            reportMetaPlist = plistlib.readPlistFromString(reportMetaBlobData)
            reportText = unicode(reportMetaPlist.get('ReproSteps', reportText))

        body=u"""
UDID: %s
Repro steps:
%s
URL: %s/manage/view?id=%s
""" % (report.udid, reportText, self.baseUrl(), str(report.key().id()))
        mail.send_mail(sender="Problem Reporter Notifications <ireporter.notifications@gmail.com>",
                  to="msft.guy <msft.guy@gmail.com>",
                  subject="New report has been submitted",
                  body=body.encode("utf8"))
  

class UploadForm(webapp.RequestHandler):
    def get(self):
        self.response.out.write(""" 
          <form method="POST" action="%s" enctype="multipart/form-data"> 
            <div>file1:<br><input type="file" name="file" size="50"/ 
></div> 
            <div>file2:<br><input type="file" name="file" size="50"/ 
></div> 
            <div>file3:<br><input type="file" name="file" size="50"/ 
></div> 
            <div>UDID: <input type="text" 
name="udid" value="test"></div>

            <div><input type="submit" value="Upload file"></div> 
          </form>""" % getUploadUrl(self))

application = webapp.WSGIApplication([('/report', ReportHandler),
                                          ('/test', UploadForm),
                                          ('/up', UploadHandler),
                                          ('/response', ResponseHandler)],
                                         debug=True)

def main():
    util.run_wsgi_app(application)


if __name__ == '__main__':
    main()
