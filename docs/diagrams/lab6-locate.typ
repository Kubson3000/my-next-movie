#import "_style.typ": *
#show: setup

#chronos.diagram({
  import chronos: *
  _par("view", display-name: "CinemaMapView", color: white)
  _par("model", display-name: "CinemaMapViewModel", color: white)
  _par("location", display-name: "Location.swift", color: white)
  _par("core", display-name: "Core Location", color: outside)
  _seq("view", "model", comment: [locateUserIfNeeded()])
  _seq("model", "location", comment: [lastKnownUserLocation()])
  _seq("location", "model", comment: [UserLocation, od razu], dashed: true)
  _seq("model", "model", comment: [znane? sortuje kina])
  _seq("model", "location", comment: [findUserLocation()])
  _seq("location", "core", comment: [liveUpdates()])
  _alt([położenie przyszło], {
    _seq("core", "location", comment: [update.location], dashed: true)
  }, [odmowa albo 10 sekund], {
    _seq("location", "location", comment: [fallbackUserLocation])
  })
  _seq("location", "model", comment: [UserLocation], dashed: true)
  _seq("model", "model", comment: [znane? sortuje kina])
  _seq("model", "view", comment: [cinemas, userLocation], dashed: true)
})
