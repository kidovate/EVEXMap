rendered = false
nodeContainer = null
svg = null
titleContainer = null
renderedMap = null
width = null
height = null
regionList = null
Template.mapControls.events
    'keyup #regionInput': ->
      region = $("#regionInput").val()
      if !(region in regionList) or region is Session.get "mapRegion"
        return
      Session.set "mapRegion", region
Meteor.startup ->
  regionList = @regions
  Session.set("mapRegion", "Cloud Ring") if !Session.get("mapRegion")?

  Template.mapControls.rendered = ->
    $("#regionInput").val(Session.get("mapRegion")).autocomplete
      lookup: regionList

  Deps.autorun ->
    region =Session.get "mapRegion"
    rerender() if renderedMap? && renderedMap isnt region

  resizeHandler = ->
    console.log "Resize handler"
    height = $("#map").height()
    width = $("#map").width()
    rerender()

  $(window).resize _.debounce resizeHandler, 400

  redraw = ->
    nodeContainer.attr "transform", "translate(" + d3.event.translate + ")" + " scale(" + d3.event.scale + ")"
  

  Template.map.rendered = ->
    height = $("#map").height()
    width = $("#map").width()
    svg = d3.select("#map").append("svg").attr("width", width).attr("height", height).attr("pointer-events", "all")
    console.log "Rerendering because of Spark render request"
    rerender()

    
  rerender = ->
    $("#map svg").empty()
    console.log "Rerendered map, "+Session.get("mapRegion")
    svg.append('svg:g').call(d3.behavior.zoom().scaleExtent([0.7, 5]).on("zoom", redraw)).append('svg:g').append('svg:rect').attr('width', width).attr('height', height).attr('fill', 'white')
    nodeContainer = svg.append('svg:g').attr('width', width).attr('height', height)
    color = d3.scale.category20()
    force = d3.layout.force().size([width, height]).charge(-200).gravity(0.05).linkDistance(30)
    d3.json "/data/"+Session.get("mapRegion").replace(" ", "_")+".json", (error, graph) ->
      #console.log graph
      svg.append("text").attr("x", (width / 2)).attr("y", '50px').style("font-weight", "bold").attr("text-anchor", "middle").style("font-size", "24px").text(Session.get("mapRegion"))
      force.nodes(graph.systems).links(graph.jumps).start()
      link = nodeContainer.selectAll(".link").data(graph.jumps).enter().append("line").attr("class", "link").style("stroke-width", (d) ->
        Math.sqrt d.value
      )
      node = nodeContainer.selectAll(".node").data(graph.systems).enter().append("g").attr("class", "node").call(force.drag)
      node.append("text").attr("dx", 12).attr("dy", ".35em").text (d) ->
        d.name
      node.append("circle").attr("r", 5).style("fill", (d)->
        if d.security is -1
          tinycolor("purple").toHex()
        else
          d.security = d.security-0.1
          if d.security < 0
            d.security = 0
          val = d.security * 100
          hue = Math.floor (val)*120/100
          saturation = 1
          color = tinycolor("hsv "+hue+" 100% 100%")
          color.toHex()
      )
    
      force.on "tick", ->
        link.attr("x1", (d) ->
          d.source.x
        ).attr("y1", (d) ->
          d.source.y
        ).attr("x2", (d) ->
          d.target.x
        ).attr "y2", (d) ->
          d.target.y
        node.attr "transform", (d)->
          "translate("+d.x+","+d.y+")"
      rendered = true
      renderedMap = Session.get "mapRegion"
