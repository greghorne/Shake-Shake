# coding: utf-8
require 'sinatra'
require 'rest-client'
require 'json'

set server: 'thin'


# ================================================
# variables ======================================
# ================================================
connections = []

seconds = 60
minutes = 15
offsetTime  = seconds.to_i * minutes.to_i

# "puts" and "console.log" statements on/off
trace = true
# ================================================


# ================================================
get '/' do
  erb :my_receiver
end
# ================================================


# ================================================
get '/streamer', provides: 'text/event-stream' do

  stream :keep_open do |out|

    # code that the server currently holds
    current_earthquake_code = ""

    # code that was just retreived from USGS
    fetched_earthquake_code  = ""

    # save connections to array
    connections << out

    # callback to remove connection from array
    out.callback{connections.delete(out)}

    if trace 
      puts "========================="
      puts "Connections Count: " + connections.count.to_s
      puts "========================="
      puts
    end

    while !out.closed?

      # rest api call to usgs
      response = getUSGS(offsetTime)

      data = ""

      # check response code
      if (response.code.to_s === "200")  then

        # parse json string
        response = JSON.parse(response)

        # count = number of earthquakes returned
        count = response['metadata']['count'].to_i

        if (trace) then 
          puts "earthquake count: " + count.to_s + "  last: " + minutes.to_s + " minutes" 
          puts ""
        end

        if count > 0 
          # retrieve the first feature (earthquake) from the rest api response
          fetched_earthquake_code = response['features'][0]['properties']['code']

          # check that the latest earthquake we have is not not equal to the latest earthquake
          # returned by usgs; if the codes are equal, then we already have and are displaying
          # the "latest" earthquake... thus do nothing to the map
          if (current_earthquake_code != fetched_earthquake_code)

            current_earthquake_code = fetched_earthquake_code

            # magnitude = response['features'][0]['properties']['mag']
            time      = response['features'][0]['properties']['time']
            code      = current_earthquake_code
            title     = response['features'][0]['properties']['title']
            lngX      = response['features'][0]['geometry']['coordinates'][0]
            latY      = response['features'][0]['geometry']['coordinates'][1]
            depth     = response['features'][0]['geometry']['coordinates'][2]

            if trace 
              puts "=========================================="
              puts "title: " + title.to_s
              puts "code:  " + code.to_s
              puts "time:  " + Time.at(time/1000).to_s
              puts "coords:" + lngX.to_s + ", " + latY.to_s
              puts "depth: " + depth.to_s + " km"
              puts "now:   " + Time.now.to_s
              puts "=========================================="
              puts 
            end

            # ==========================================================================================
            # the string sent from the server to the client must start with "data:" and end with "\n\n"
            # ==========================================================================================
            data = "data: {\"msg\":\"" + title.to_s + "\",\"x\":" + lngX.to_s + ",\"y\":" + latY.to_s + ",\"z\":" + depth.to_s + ",\"utc\":\"" + Time.at(time/1000).to_s + "\"}\n\n"
          end
        end

        if (data === "") then
          data = "data: {\"msg\":\"0\",\"usgs earthquake count\":" + count.to_s + ",\"in recent minutes\":" + minutes.to_s + "}\n\n"
        end

        # send data to client
        out << data
      else
        # most often, server was down (or not responding)
        puts "REST API Call: " + response.code.to_s
      end
      sleep 30
    end
  end
end
# ================================================

# ================================================
def getUSGS(offsetTime)

  # offsetTime = seconds

  # USGS REST API
  https = 'https://earthquake.usgs.gov/fdsnws/event/1/query'

  response = RestClient.get https, {
    params: {
      :format     => 'geojson',
      :starttime  => Time.now.utc - offsetTime,
      :orderby    => 'time',
      :eventtype  => 'earthquake'
    }
  }

  return response
end
# ================================================


__END__

@@ layout
<html>
  <head> 
    <title>Shake-Shake</title> 

    <meta charset="utf-8" />

    <link rel="icon" href="/images/earthquakes.ico" type="image/x-icon"/>

    <!-- CSS     -->
    <link rel="stylesheet" href="/stylesheet.css">
    <link rel="stylesheet" href="/leaflet.css" crossorigin=""/>
    <link rel="stylesheet" href="/jquery-ui.css">
    <link rel="stylesheet" href="/alertify.min.css">
    
    <!-- JS -->
    <script src="/jquery-1.12.4.js"></script>
    <script src="/leaflet.js"  crossorigin=""></script>
    <script src="/jquery-ui.js"></script>
    <script src="/alertify.min.js"></script>
    <script src="/bouncemarker.js"></script>

  </head> 
  <body><%= yield %></body>
</html>


@@ my_receiver
<pre id='my_receiver'></pre>

<script>

  if (typeof(EventSource) !== "undefined") {

    var firstTime = true;
    var marker;
    var trace = true; 

    $(document).ready(function() {

      var eventSource = new EventSource('/streamer');

      // =======================================
      // event - message =======================
      // =======================================
      eventSource.addEventListener('message', function(event){

        var divText = "";

        json = JSON.parse(event.data);
        if (json['msg'] != "0") {

          firstTime = false;
          
          if (trace) console.log(json);

          // extract some data from json object
          longitudeX = json['x'];
          latitudeY  = json['y'];
          msg        = json['msg'];
          depth      = json['z'];
          time       = json['utc'];

          // if any, remove current map marker
          if (marker !== undefined) map.removeLayer(marker);

          // add new marker to map
          marker = L.marker([latitudeY, longitudeX]).addTo(map);

          // ================================================================================
          // pan and zoom to new map (earthquake) location
          // ================================================================================
          // unknown reason; if the webpage's tab is not active, the map.flyTo() fails
          // no error is thrown but the earthquake location is not centered on the map
          // thus if tab is not active, just change the map view to the new location 
          // i.e. don't flyTo() the location
          // ================================================================================
          if (!document.hidden) map.flyTo([latitudeY, longitudeX], 8)
          else map.setView(L.latLng(latitudeY, longitudeX), 8);
          // ================================================================================
    
          divText = "";

          setTimeout(function() {
            $("#map").effect("shake", {times: 5, direction: "up"});
            marker.bounce({duration: 2000, height: 250})
            marker.bindPopup("<center>" + msg + "<br>Depth: " + depth + " km<br>UTC: " + time + "<center>").openPopup();
          }, 4000);

        } else {

          if (firstTime) {
            alertify.warning("<center>No recent data available from USGS.<br/>Please wait for an event...</center>")

            firstTime = false;
          }
          if (trace) console.log(json);

          var count = json["usgs earthquake count"]

          // color text differently based on the number of recent earthquakes
          if (count === 0) $("#msg").css('color', 'rgb(165,255,144)') // green-ish
          else if (count < 6) $("#msg").css('color', 'yellow')
          else $("#msg").css('color', 'rgb(245,107,97)')              // red-ish

          var date = new Date();
          json['msg'] = date;

          // set value of info text
          divText = date + " === USGS Earthquake Count: " + json["usgs earthquake count"] + " (last " + json["in recent minutes"] + " minutes)"
        }
        // commented out message that appaears on bottom of webpage
        // $("#msg").text(divText);

      }, false);
      // =======================================


      // =======================================
      // event - error =========================
      // =======================================
      eventSource.addEventListener('error', function(event) {
        // if this event fires it will automatically try and reconnect
        if (trace) {
          console.log("--------------------")
          console.log("error...")
          console.log(event)
          console.log("--------------------")
        }
      }, false);
      // =======================================


      // =======================================
      // event - close =========================
      // =======================================
      eventSource.addEventListener('close', function(event) {
        if (trace) {
          console.log("--------------------")
          console.log("connection closed...")
          console.log(event)
          console.log("--------------------")
        }
      }, false)
      // =======================================


      // =======================================
      // leaflet begin >>>>>>>>>>>>>>>>>>>>>>>>>
      // =======================================

      // initial map settings/view
      var latitude = 35.746512259918504
      var longitude = -96.9873046875
      var zoom = 4

      // kudos
      var attributionTOPO = 'Map data: &copy; <a href="http://www.openstreetmap.org/copyright">OpenStreetMap</a>, <a href="http://viewfinderpanoramas.org">SRTM</a> | Map style: &copy; <a href="https://opentopomap.org">OpenTopoMap</a> (<a href="https://creativecommons.org/licenses/by-sa/3.0/">CC-BY-SA</a>)'

      // define map street layer
      var osm = L.tileLayer('https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png', {  
        attribution: attributionTOPO
      });

      // init map x, y and zoom and map layer
      var map = L.map('map', {
        center: [latitude, longitude],
        zoom: zoom,
        layers: [osm]
      });

      // scalebar
      L.control.scale().addTo(map);

      // =================================================
      // add help <img> to map
      // =================================================
      L.Control.Help = L.Control.extend({
          onAdd: function(map) {
              var img = L.DomUtil.create('img');

              img.src = '/images/help1.png';
              img.addEventListener('click', function () {
                openNav();
              })
              return img;
          },
      });

      L.control.help = function(opts) {
          return new L.Control.Help(opts);
      }

      L.control.help({ position: 'topright' }).addTo(map);
      // =================================================

    });

    // =========================================================
    function openNav() {
        document.getElementById("myNav").style.height = "100%";
        document.getElementById("myNav").style.width = "100%";
    }
    // =========================================================

    // =========================================================
    function closeNav() {
        document.getElementById("myNav").style.height = "0%";
        document.getElementById("myNav").style.width = "0%";
    }
    // =========================================================

  } else {
    // =========================================================
    // EventSource not supported
    // =========================================================
    alert("Server-Sent Events are not supported with your browser.")
    // =========================================================
  };

</script>


<div id="myNav" class="overlay" onclick="closeNav();">
  <a class="closebtn" onclick="closeNav();" style=cursor:pointer>&times;</a>

  <div class="overlay-content"><h1>Shake-Shake</h1>
    <img src="/images/earthquake.png" height="96" width="96">
    <br><br>Display the latest earthquake on a map based on USGS information.
    <br><br>Server-Sent Events are used in this webapp to send earthquake information from the server to the client (one-way-feed).  Please note that Server-Sent Events are not supported by IE/Edge at this writing. 
    <br><br>The server sends data to the client browser approximately every 30 seconds.  
    <br>The data being sent can be observed through the console window of the browser. 
    <br><br>Note that earthquake information is not necessarily instantaneous meanings an earthquake that occurred 10 minutes ago may only be available through the USGS in the last few minutes.
    <br><br>This website is hosted on a Raspberry Pi.
    <br><br><a style=color:yellow href="https://github.com/greghorne/push_sinatra" target="_blank">GitHub Repository</a>
    <br><br><br><a href="https://www.ruby-lang.org" target="_blank"><img src="/images/Ruby_logo.svg" class="image_type1"></a>
    &nbsp;&nbsp;<a href="http://www.sinatrarb.com" target="_blank"><img src="/images/sinatra.png" class="image_type1"></a>
    &nbsp;&nbsp;<a href="https://www.javascript.com" target="_blank"><img src="/images/js2.png" class="image_type1"></a>
    &nbsp;&nbsp;<a href="https://earthquake.usgs.gov/fdsnws/event/1/" target="_blank"><img src="/images/usgs.jpg" class="image_type2"></a>
    &nbsp;&nbsp;<a href="http://leafletjs.com" target="_blank"><img src="/images/leaflet.png" class="image_type3"></a>
    &nbsp;&nbsp;<a href="https://wiki.openstreetmap.org/wiki/Main_Page" target="_blank"><img src="/images/osm.png" class="image_type1"></a>
  </div>
</div>  

<div id='map'></div>
<div class="vertical-container"><div id="msg"></div></div>


