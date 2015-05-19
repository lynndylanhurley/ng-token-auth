process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';
var express   = require('express');
var request   = require('request');
var s3Policy  = require('./server/s3');
var sm        = require('sitemap');
var os        = require('os');

var port    = process.env.PORT || 7777;
var distDir = '/.tmp';
var app     = express();

// must override env and then init CONFIG
process.env.NODE_CONFIG_DIR = './test/config'
var CONFIG = require('config');

console.log('@-->API URL', CONFIG.API_URL);
console.log('@-->NODE_ENV', process.env.NODE_ENV);

// env setup
// TODO: comment this better
if (process.env.NODE_ENV && process.env.NODE_ENV != 'development' && process.env.NODE_ENV != 'travis') {
  distDir = '/dist-'+process.env.NODE_ENV.toLowerCase();
} else {
  app.use(require('connect-livereload')());
}

// sitemap
sitemap = sm.createSitemap({
  hostname: CONFIG.SITE_DOMAIN,
  cacheTime: 600000,
  urls: [
   { url: '/', changefreq: 'monthly', priority: 0.9 }
  ]
});

app.get('/sitemap.xml', function(req, res) {
  sitemap.toXML(function(xml) {
    res.header('Content-Type', 'application/xml');
    res.send(xml);
  });
});


// proxy api requests (for older IE browsers)
app.all('/proxy/*', function(req, res, next) {
  // transform request URL into remote URL
  var apiUrl = 'http:'+CONFIG.API_URL+'/'+req.params[0];
  var r = null;

  // preserve GET params
  if (req._parsedUrl.search) {
    apiUrl += req._parsedUrl.search;
  }

  // handle POST / PUT
  if (req.method === 'POST' || req.method === 'PUT') {
    r = request[req.method.toLowerCase()]({uri: apiUrl, json: req.body});
  } else {
    r = request(apiUrl);
  }

  // pipe request to remote API
  req.pipe(r).pipe(res);
});

// provide s3 policy for direct uploads
app.get('/policy/:fname', function(req, res) {
  var fname       = req.params.fname;
  var contentType = 'image/png';
  var acl         = 'public-read';
  var uploadDir   = CONFIG.aws_upload_dir;

  var policy = s3Policy({
    expiration: "2014-12-01T12:00:00.000Z",
    dir:        uploadDir,
    bucket:     CONFIG.aws_bucket,
    secret:     CONFIG.aws_secret,
    key:        CONFIG.aws_key,
    acl:        acl,
    type:       contentType
  });

  res.send({
    policy: policy,
    path:   "//"+CONFIG.aws_bucket+".s3.amazonaws.com/"+uploadDir+fname,
    action: "//"+CONFIG.aws_bucket+".s3.amazonaws.com/"
  });
});

// redirect to push state url (i.e. /blog -> /#/blog)
app.get(/^(\/[^#\.]+)$/, function(req, res) {
  var path = req.route.params[0]

  // preserve GET params
  if (req._parsedUrl.search) {
    path += req._parsedUrl.search;
  }

  res.redirect('/#'+path);
});

app.use(express.static(__dirname + distDir));
app.listen(port);
