AutoWatcher =
  init: ->
    return unless Conf['Filter']

    AutoWatcher.periodicScan()

  periodicScan: ->
    clearTimeout AutoWatcher.timeout
    console.log("scanning")

    interval = 5 * $.MINUTE

    now = Date.now()

    unless Conf['autoWatchLastScan'] and (now - interval < Conf['autoWatchLastScan'])
      AutoWatcher.scan()
    AutoWatcher.timeout = setTimeout AutoWatcher.periodicScan, interval

  scan: ->
    sitesAndBoards = (for own _, filters of Filter.filters
      Object.keys(filter.boards) for filter in filters when filter.watch and filter.boards
    ).flat(2).reduce (acc, i) ->
      [_, k, v] = i.match(/(.*)\/(.*)/)
      acc[k] ?= []
      acc[k].push(v)
      acc
    , {}
    for own rawSite, boards of sitesAndBoards
      break unless site = g.sites[rawSite]
      for boardID in boards
        AutoWatcher.fetchCatalog(boardID, site, AutoWatcher.parseCatalog)

  fetchCatalog: (boardID, site, cb) ->
    return unless url = site.urls['catalogJSON']?({boardID})

    ajax = if site.ID is g.SITE.ID then $.ajax else CrossOrigin.ajax

    onLoadEnd = ->
      cb.apply @, [site, boardID]

    $.whenModified(
      url,
      'AutoWatcher'
      onLoadEnd,
      {timeout: $.MINUTE, ajax}
    )

  parseCatalog: (site, boardID) ->
    rawCatalog = @.response.reduce ((acc, i) -> acc.concat(i.threads)), []
    for thread in rawCatalog
      # TODO: Add early bailout to skip threads we're already watching
      parsedThread = site.Build.parseJSON(thread, {siteID: site.ID, boardID})

      # I wish destructuring was actually pattern matching
      {watch} = Filter.test(parsedThread)

      debugger
      # TODO: figure out where isDead is coming from
      # TODO: break out thread values into param list for addRaw
      ThreadWatcher.addRaw({parsedThread) if watch
