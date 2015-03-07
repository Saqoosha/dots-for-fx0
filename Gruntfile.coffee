module.exports = (grunt) ->

  grunt.initConfig

    sass:
      all:
        expand: true
        flatten: true
        src: ['src/*.sass']
        dest: 'dist/assets'
        ext: '.css'
      options:
        sourcemap: 'none'

    autoprefixer:
      all:
        expand: true
        flatten: true
        src: ['dist/assets/*.css']
        dest: 'dist/assets'
        ext: '.css'

    cssmin:
      options:
        report: 'gzip'
      dist:
        files:
          'dist/assets/main.css': 'dist/assets/main.css'

    browserify:
      dev:
        files:
          'dist/assets/bundle.js': 'src/Main.coffee'
        options:
          browserifyOptions:
            debug: true
            extensions: ['.coffee']
      dist:
        files:
          'dist/assets/bundle.js': 'src/Main.coffee'
        options:
          browserifyOptions:
            debug: false
            extensions: ['.coffee']
            fullPaths: false
      options:
        watch: true
        transform: [
          'coffeeify'
          'browserify-shim'
        ]

    uglify:
      'dist/assets/bundle.js': 'dist/assets/bundle.js'
      options:
        report: 'gzip'

    watch:
      sass:
        files: ['src/**/*.sass']
        tasks: ['sass', 'autoprefixer']
      dist:
        files: ['dist/**/*']
        options:
          livereload: true

    connect:
      server:
        options:
          base: 'dist'
          hostname: '*'


  grunt.loadNpmTasks('grunt-contrib-sass')
  grunt.loadNpmTasks('grunt-autoprefixer')
  grunt.loadNpmTasks('grunt-contrib-cssmin')
  grunt.loadNpmTasks('grunt-browserify')
  grunt.loadNpmTasks('grunt-contrib-uglify')
  grunt.loadNpmTasks('grunt-contrib-watch')
  grunt.loadNpmTasks('grunt-contrib-connect')
  grunt.registerTask('default', ['connect', 'sass', 'autoprefixer', 'browserify:dev', 'watch'])
  grunt.registerTask('build', ['sass', 'autoprefixer', 'cssmin', 'browserify:dist', 'uglify'])
