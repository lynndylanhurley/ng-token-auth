'use strict';

// config is in non-standard location. setting this env var will direct
// node-config to the proper config files.
process.env.NODE_CONFIG_DIR = './test/config'

var gulp     = require('gulp');
var wiredep  = require('wiredep').stream;
//var sprite   = require('css-sprite').stream;
var config   = require('config');
var cached   = require('gulp-cached');
var es       = require('event-stream');
var seq      = require('run-sequence');
var lazypipe = require('lazypipe');
var nib      = require('nib');
var ngAnnotate = require('gulp-ng-annotate');

var appDir = 'test/app/'
var distDir = 'test/dist/'
var tmpDir = 'test/.tmp/'

var componentSrcDir  = 'src/'
var componentDistDir = 'dist/'

// for deployment
var env             = (process.env.NODE_ENV || 'development').toLowerCase();
var tag             = env + '-' + new Date().getTime();
var DIST_DIR        = distDir;
var LIVERELOAD_PORT = 35729;

if (process.env.NODE_ENV) {
  DIST_DIR = 'test/dist-'+process.env.NODE_ENV.toLowerCase();
}

// Load plugins
var $ = require('gulp-load-plugins')();

// Sass
gulp.task('sass', function () {
  return gulp.src(appDir+'styles/deps.scss')
    .pipe(cached('sass'))
    .pipe($.rubySass({
      style: 'expanded',
      loadPath: [appDir+'bower_components']
    }))
    .pipe($.autoprefixer('last 1 version'))
    .pipe(wiredep({
      directory: appDir+'/bower_components',
      ignorePath: appDir+'/bower_components/'
    }))
    .pipe(gulp.dest(tmpDir+'/styles'))
    .pipe($.size());
});


// JS
gulp.task('js', function () {
  return gulp.src(appDir+'scripts/**/*.js')
    .pipe(cached('js'))
    .pipe($.jshint('.jshintrc'))
    .pipe($.jshint.reporter('default'))
    .pipe(gulp.dest(tmpDir+'/scripts'))
    .pipe($.size());
});

// Bower
gulp.task('bowerjs', function() {
  return gulp.src(appDir+'bower_components/**/*.js')
    .pipe(gulp.dest(tmpDir+'/bower_components'))
    .pipe($.size());
});

gulp.task('bowercss', function() {
  return gulp.src(appDir+'bower_components/**/*.css')
    .pipe(gulp.dest(tmpDir+'/bower_components'))
    .pipe($.size());
});

// TODO: what a mess. maybe move all fonts into one dir?
gulp.task('bower-fonts', function() {
  return gulp.src([
    appDir+'bower_components/bootstrap-sass-official/assets/fonts/bootstrap/*.*',
    appDir+'bower_components/font-awesome/fonts/*.*'
  ])
    .pipe(gulp.dest(tmpDir+'/fonts'))
    .pipe($.size());
})

// CoffeeScript
gulp.task('coffee', function() {
  return gulp.src(appDir+'scripts/**/*.coffee')
    .pipe(cached('coffee'))
    .pipe($.coffee({bare: true}))
    .on('error', function(e) {
      $.util.log(e.toString());
      this.emit('end');
    })
    .pipe(gulp.dest(tmpDir+'/scripts'))
    .pipe($.size());
});

gulp.task('component-coffee', function() {
  return gulp.src(componentSrcDir+'**/*.coffee')
    .pipe(cached('component-coffee'))
    .pipe($.coffee({bare: true}))
    .on('error', function(e) {
      $.util.log(e.toString());
      this.emit('end');
    })
    .pipe(ngAnnotate())
    .pipe(gulp.dest(componentDistDir))
    .pipe(gulp.dest(tmpDir + 'scripts/'))
    .pipe($.uglify())
    .pipe($.rename('ng-token-auth.min.js'))
    .pipe(gulp.dest(componentDistDir))
    .pipe($.size());
});

// Images
gulp.task('images', function () {
  return gulp.src(appDir+'images/**/*')
    .pipe(gulp.dest(tmpDir+'/images'))
    .pipe($.size());
});


gulp.task('css', function() {
  return gulp.src(appDir+'styles/**/*.css')
    .pipe(gulp.dest(tmpDir+'/styles'))
    .pipe($.size());
});

// Stylus
gulp.task('stylus', function() {
  return gulp.src(appDir+'styles/main.styl')
    .pipe($.stylus({
      paths: [appDir+'styles', tmpDir+'/styles'],
      //set: ['compress'],
      use: [nib()],
      import: [
        //'sprite',
        'globals/*.styl',
        'pages/**/*.xs.styl',
        'pages/**/*.sm.styl',
        'pages/**/*.md.styl',
        'pages/**/*.lg.styl',
        'degrade.styl'
      ]
    }))
    .on('error', function(e) {
      $.util.log(e.toString());
      this.emit('end');
    })
    .pipe(gulp.dest(tmpDir+'/styles'))
    .pipe($.size());
});

// Clean
gulp.task('clean', function () {
  return gulp.src([distDir+'/*', tmpDir+'/*'], {read: false}).pipe($.clean());
});

// Transpile
gulp.task('transpile', [
  'stylus',
  'coffee',
  'component-coffee',
  'js',
  'css',
  'bowerjs',
  'bowercss',
  'bower-fonts'
]);

// jade -> html
var jadeify = lazypipe()
  .pipe($.jade, {
    pretty: true
  });

// inject global js vars
var injectGlobals = lazypipe()
  .pipe($.frep, [
    {
      pattern: '@@GLOBALS',
      replacement: JSON.stringify({
        apiUrl: config.API_URL
      })
    }
  ]);

// Jade to HTML
gulp.task('base-tmpl', function() {
  return gulp.src(appDir+'index.jade')
    .pipe($.changed(tmpDir))
    .pipe(jadeify())
    .pipe(injectGlobals())
    .pipe($.inject($.bowerFiles({
      paths: {bowerJson: "test/bower.json"},
      read: false
    }), {
      ignorePath: [appDir],
      starttag: '<!-- bower:{{ext}}-->',
      endtag: '<!-- endbower-->'
    }))
    .pipe($.inject(gulp.src(
      [
        tmpDir+'/views/**/*.js',
        tmpDir+'/scripts/**/*.js',
        tmpDir+'/styles/**/*.css'
      ],
      {read: false}
    ), {
      ignorePath: [tmpDir],
      starttag: '<!-- inject:{{ext}}-->',
      endtag: '<!-- endinject-->'
    }))
    .pipe(gulp.dest(tmpDir))
    .pipe($.size());
});

// Jade to JS
gulp.task('js-tmpl', function() {
  return gulp.src(appDir+'views/**/*.jade')
    .pipe(cached('js-tmpl'))
    .pipe(jadeify())
    .pipe($.ngHtml2js({
      moduleName: 'ngTokenAuthTestPartials'
    }))
    .pipe(gulp.dest(tmpDir+'/views'));
});

// useref
gulp.task('useref', function () {
  $.util.log('running useref');
  var jsFilter = $.filter(tmpDir+'/**/*.js');
  var cssFilter = $.filter(tmpDir+'/**/*.css');

  return es.merge(
    gulp.src(tmpDir+'/images/**/*.*', {base: tmpDir}),
    gulp.src(tmpDir+'/fonts/**/*.*', {base: tmpDir}),
    gulp.src(tmpDir+'/index.html', {base: tmpDir})
      .pipe($.useref.assets())
      .pipe(jsFilter)
      .pipe($.uglify())
      .pipe(jsFilter.restore())
      .pipe(cssFilter)
      .pipe($.minifyCss())
      .pipe(cssFilter.restore())
      .pipe($.useref.restore())
      .pipe($.useref())
    )
    .pipe(gulp.dest(tmpDir))
    .pipe($.if(/^((?!(index\.html)).)*$/, $.rev()))
    .pipe(gulp.dest(distDir))
    .pipe($.rev.manifest())
    .pipe(gulp.dest(tmpDir))
    .pipe($.size());
});

// Update file version refs
gulp.task('replace', function() {
  var manifest = require('./'+tmpDir+'rev-manifest');

  var patterns = []
  for (var k in manifest) {
    patterns.push({
      pattern: k,
      replacement: manifest[k]
    });
  };

  return gulp.src([
    distDir+'/*.html',
    distDir+'/styles/**/*.css',
    distDir+'/scripts/main*.js'
  ], {base: distDir})
    .pipe($.frep(patterns))
    .pipe(gulp.dest(distDir))
    .pipe($.size());
});

// CDNize
gulp.task('cdnize', function() {
  return gulp.src([
    distDir+'/*.html',
    distDir+'/styles/**/*.css'
  ], {base: distDir})
    .pipe($.cdnizer({
      defaultCDNBase: config.STATIC_URL,
      allowRev: true,
      allowMin: true,
      files: ['**/*.*']
    }))
    .pipe(gulp.dest(distDir))
    .pipe($.size());
});


// Deployment
gulp.task('s3', function() {
  var envName = (process.env.NODE_ENV || 'development').toLowerCase();
  var headers = {
    'Cache-Control': 'max-age=315360000, no-transform, public'
  };
  var publisher = $.awspublish.create({
    key:    config.AWS_KEY,
    secret: config.AWS_SECRET,
    bucket: config.AWS_STATIC_BUCKET_NAME
  });

  return gulp.src(distDir+'/**/*')
    .pipe($.awspublish.gzip())
    .pipe(publisher.publish(headers))
    .pipe(publisher.sync())
    //.pipe(publisher.cache())
    .pipe($.awspublish.reporter());
});

// Push to heroku
gulp.task('push', $.shell.task([
  'git checkout -b '+tag,
  'cp -R '+distDir+' '+DIST_DIR,
  'cp test/config/'+env+'.yml test/config/default.yml',
  'git add -u .',
  'git add .',
  'git commit -am "commit for '+tag+' push"',
  'git push -f '+env+' '+tag+':master',
  'git checkout master',
  'git branch -D '+tag,
  'rm -rf '+DIST_DIR
]));


// E2E Protractor tests
gulp.task('protractor', function() {
  require('coffee-script/register');
  return gulp.src('test/e2e/**/*.coffee')
    .pipe($.protractor.protractor({
      configFile: 'protractor.conf.js'
    }))
    .on('error', function(e) {
      $.util.log(e.toString());
      this.emit('end');
    });
});

gulp.task('test:e2e', ['protractor'], function() {
  gulp.watch('test/e2e/**/*.coffee', ['protractor']);
});

// Watch
gulp.task('watch', function () {
  var lr      = require('tiny-lr')();
  var nodemon = require('gulp-nodemon');

  // start node server
  $.nodemon({
    script: 'test/app.js',
    ext: 'html js',
    ignore: [],
    watch: []
  })
    .on('restart', function() {
      console.log('restarted');
    });

  // start livereload server
  lr.listen(LIVERELOAD_PORT);

  // Watch for changes in .tmp folder
  gulp.watch([
    tmpDir+'/*.html',
    tmpDir+'/styles/**/*.css',
    tmpDir+'/scripts/**/*.js',
    tmpDir+'/images/**/*.*'
  ], function(event) {
    gulp.src(event.path, {read: false})
      .pipe($.livereload(lr));
  });

  // Watch .scss files
  gulp.watch(appDir+'styles/**/*.scss', ['sass']);

  // Watch .styl files
  gulp.watch(appDir+'styles/**/*.styl', ['stylus']);

  // Watch sprites
  //gulp.watch(appDir+'images/sprites/**/*.png', ['sprites']);

  // Watch .js files
  gulp.watch(appDir+'scripts/**/*.js', ['js']);

  // Watch .coffee files
  gulp.watch(appDir+'scripts/**/*.coffee', ['coffee']);

  // Watch bower component
  gulp.watch(componentSrcDir+'**/*.coffee', ['component-coffee']);

  // Watch .jade files
  gulp.watch(appDir+'index.jade', ['base-tmpl'])
  gulp.watch(appDir+'views/**/*.jade', ['reload-js-tmpl'])

  // Watch image files
  gulp.watch(appDir+'images/**/*', ['images']);

  // Watch bower files
  gulp.watch(appDir+'bower_components/*', ['bowerjs', 'bowercss']);
});

// Composite tasks
// TODO: refactor when gulp adds support for synchronous tasks.
// https://github.com/gulpjs/gulp/issues/347
gulp.task('build-dev', function(cb) {
  seq(
    'clean',
    //'sprites',
    'images',
    'sass',
    'transpile',
    'js-tmpl',
    'base-tmpl',
    cb
  );
});

gulp.task('dev', function(cb) {
  seq('build-dev', 'watch', cb);
});

gulp.task('reload-js-tmpl', function(cb) {
  seq('js-tmpl', 'base-tmpl', cb);
});

gulp.task('build-prod', function(cb) {
  seq(
    'build-dev',
    'useref',
    'replace',
    //'cdnize',
    //'s3',
    cb
  );
});

gulp.task('deploy', function(cb) {
  if (!process.env.NODE_ENV) {
    throw 'Error: you forgot to set NODE_ENV'
  }
  seq('build-prod', 'push', cb);
});
