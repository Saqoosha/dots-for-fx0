$ = require('jquery')
_ = require('underscore')
Snap = require('snapsvg')
THREE = require('three')
QUAD = require('./quadtree')
TWEEN = require('tween.js')
#Stats = require('stats-js')
Detector = require('./Detector')

SVGRenderer = require('./renderers/SVGRenderer')
WebGLRenderer = require('./renderers/WebGLRenderer')

DotEvents = require('./Events')

Dot = require('./Dot')
Yusuke = require('./patterns/Yusuke')
Heri = require('./patterns/Heri')
Saqoosha = require('./patterns/Saqoosha')
Seki = require('./patterns/Seki')
Sfman = require('./patterns/Sfman')
Hige = require('./patterns/Hige')
Taichi = require('./patterns/Taichi')
Jaguar = require('./patterns/Jaguar')

Data = require('./data')

# window.requestAnimationFrame = Modernizr.prefixed('requestAnimationFrame') or (c) -> window.setTimeout(c, 1000 / 60)


class ShuffledArray

  constructor: (@data) ->
    @prev = -1

  next: =>
    while true
      next = ~~(Math.random() * @data.length)
      if @prev isnt next then break
    @prev = next
    return @data[next]




class Dots


  constructor: (container) ->
    if Detector.webgl
      @renderer = new WebGLRenderer(container)
    else
      @renderer = new SVGRenderer(container)
    @quadtree = QUAD.init(x: 0, y: 0, w: window.innerWidth, h: innerHeight)
    @currentDots = []
    @currentPattern = null
    @currentColor = r: 255, g: 255, b: 255
    @t = 0

    patterns = new ShuffledArray([Saqoosha, Yusuke, Sfman, Heri, Seki, Hige, Taichi, Jaguar])
#    patterns = new ShuffledArray([Jaguar, Taichi])
    colors = new ShuffledArray(_.values(Data.members).map((item) => item.color.substr(1)))
    tr = =>
      @transitionTo(patterns.next(), colors.next()).done ->
        setTimeout(tr, 800)
    tr()

    # setTimeout =>
    #   @transitionTo(Yusuke, Snap.color('#E62172')).done =>
    #     setTimeout =>
    #       @transitionTo(Heri, Snap.color('#E62172'), 10000)
    #     , 1000
    # , 1000

    # @stats = new Stats()
    # document.body.appendChild(@stats.domElement)

    $(window).on('resize', @_onResize)
    setInterval(@_onResize, 1000)
    @_onResize()

    DotEvents.addListener('saveAsPNG', @saveAsPNG)

    @epoc = Date.now()
    @animate()


  byDistance = (a, b) -> a.dist - b.dist

  transitionTo: (patternClass, nextColor, duration = 350) =>
    delete @currentPattern

    deferred = $.Deferred()

    added = []
    moved = []
    willRemoved = []

    nextPattern = new patternClass()
    nextDots = nextPattern.getDots(window.innerWidth, window.innerHeight)

    @quadtree.clear()
    for dot in nextDots
      obj = 
        x: dot.x - dot.radius
        y: dot.y - dot.radius
        w: dot.radius * 2
        h: dot.radius * 2
        dot: dot
      @quadtree.insert(obj)

    candidates = {}
    nextTaken = {}
    for dot in @currentDots
      minDist = Number.MAX_VALUE
      dot.prev = dot.next
      dot.next = null
      next = null
      r = dot.radius
      r2 = r * 2
      selector = x: dot.x - r, y: dot.y - r, w: r2, h: r2
      @quadtree.retrieve(selector, (node) ->
        dx = dot.x - node.dot.x
        dy = dot.y - node.dot.y
        dist = dx * dx + dy * dy
        d = Math.max(20, dot.radius) + Math.max(20, node.dot.radius)
        if dist < d * d
          candidates[node.dot.id] ?= []
          candidates[node.dot.id].push(dot: dot, dist: dist)
          if dist < minDist
            minDist = dist
            next = node.dot
        )
      if next
        dot.next = next
        if next.prev and nextTaken[next.id]
          willRemoved.push(dot)
        else
          next.prev = dot
          nextTaken[next.id] = true
      else
        dot.next = new Dot(dot.x, dot.y, 0)
        willRemoved.push(dot)

    for dot in nextDots
      prevs = candidates[dot.id]
      if prevs?.length
        prevs.sort(byDistance)
        prev = prevs[0].dot
        if prev.next.id isnt dot.id
          if nextTaken[dot.id]
            willRemoved.push(new Dot(prev.x, prev.y, prev.raius, prev, dot))
          else
            added.push(new Dot(prev.x, prev.y, prev.raius, prev, dot))
            nextTaken[dot.id] = true
      else
        prev = new Dot(dot.x, dot.y, 0)
        added.push(new Dot(dot.x, dot.y, 0, prev, dot))

    # console.log('added', added.length, 'moved', moved.length, 'willRemoved', willRemoved.length)
    dots = @currentDots = @currentDots.concat(added, moved, willRemoved)

    @runningPatterns = [@currentPattern, nextPattern]

    @t = 0
    new TWEEN.Tween(this).to(t: 1, duration).easing(TWEEN.Easing.Cubic.InOut).onComplete(=>
        if willRemoved.length
          willRemoved.unshift(@currentDots)
          @currentDots = _.without.apply(null, willRemoved)
        @currentPattern = nextPattern
        deferred.resolve()
      ).start()

    nextColor = Snap.color('#' + nextColor)
    new TWEEN.Tween(@currentColor).to(r: nextColor.r, g: nextColor.g, b: nextColor.b, duration).easing(TWEEN.Easing.Cubic.InOut).onUpdate(=>
      @renderer.setColor(@currentColor.r, @currentColor.g, @currentColor.b)
      DotEvents.emit('colorChanged', Snap.rgb(@currentColor.r, @currentColor.g, @currentColor.b))
      ).start()

    return deferred.promise()


  animate: =>
    requestAnimationFrame(@animate)

    TWEEN.update()
    @currentPattern?.animate()

    t = @t
    s = 1 - t
    for dot in @currentDots
      prev = dot.prev
      next = dot.next
      dot.x = prev.x * s + next.x * t
      dot.y = prev.y * s + next.y * t
      dot.radius = prev.radius * s + next.radius * t

    @renderer.update(@currentDots)

    # @stats.update()


  windowWidth = -1
  windowHeight = -1

  _onResize: =>
    if windowWidth isnt innerWidth or windowHeight isnt innerHeight
      windowWidth = innerWidth
      windowHeight = innerHeight
      @renderer.setSize(innerWidth, innerHeight)


  saveAsPNG: =>
    canvas = document.createElement('canvas')
    dpr = devicePixelRatio or 1
    canvas.width = screen.width * dpr
    canvas.height = screen.height * dpr
    ctx = canvas.getContext('2d')
    ctx.fillStyle = 'white'
    ctx.fillRect(0, 0, canvas.width, canvas.height)
    s = Math.max(canvas.width / windowWidth, canvas.height / windowHeight)
    ctx.translate(-(windowWidth * s - canvas.width) / 2, -(windowHeight * s - canvas.height) / 2)
    ctx.scale(s, s)
    ctx.fillStyle = Snap.rgb(@currentColor.r, @currentColor.g, @currentColor.b)
    for dot in @currentDots
      ctx.beginPath()
      ctx.arc(dot.x, dot.y, dot.radius, 0, Math.PI * 2, false)
      ctx.closePath()
      ctx.fill()

    ctx.fillStyle = 'rgba(0, 0, 0, 0.05)'
    dx = Math.max(windowWidth, windowHeight, 800) / 14
    dy = dx / 2
    r = dx * 0.2
    y = 0
    even = false
    while y < windowHeight + dy
      x = if even then -dx / 2 else 0
      while x < windowWidth + dx
        ctx.beginPath()
        ctx.arc(x, y, r, 0, Math.PI * 2, false)
        ctx.closePath()
        ctx.fill()
        x += dx
      y += dy
      even = not even

    window.open(canvas.toDataURL('image/png'))


new Dots(document.querySelector('#dots'))

