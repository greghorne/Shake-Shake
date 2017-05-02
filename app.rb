# coding: utf-8
require 'sinatra'
require 'rest-client'
require 'json'

set server: 'thin'


# ================================================
# variables ======================================
# ================================================
connections = []

# 60 (seconds) * minutes
minutes = 15
offsetTime  = 60 * minutes.to_i

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
          else
            # data = "data: {\"msg\":\"0\",\"usgs earthquake count\":" + count.to_s + ",\"in recent minutes\":" + minutes.to_s + "}\n\n"
          end
        else
          # data = "data: {\"msg\":\"0\",\"usgs earthquake count\":" + count.to_s + ",\"in recent minutes\":" + minutes.to_s + "}\n\n"
        end

        if (data === "") then
          data = "data: {\"msg\":\"0\",\"usgs earthquake count\":" + count.to_s + ",\"in recent minutes\":" + minutes.to_s + "}\n\n"
        end

        out << data
        sleep 30

      else
        # most often, server was down (or not responding)
        puts "REST API Call: error"
      end
    end

  end
end
# ================================================

# ================================================
def getUSGS(offsetTime)

  # USGS REST API
  https = 'https://earthquake.usgs.gov/fdsnws/event/1/query'

  response = RestClient.get https, {
    params: {
      :format => 'geojson',
      :starttime => Time.now.utc - offsetTime,
      :orderby => 'time',
      :eventtype => 'earthquake'
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
    <link rel="icon" href="earthquakes.ico" type="image/x-icon"/>
    
    <link rel="stylesheet" href="/leaflet.css" crossorigin=""/>
    <link rel="stylesheet" href="/jquery-ui.css">
    
    <!--<script src="https://code.jquery.com/jquery-1.12.4.js"></script>-->
    <script src="/jquery-1.12.4.js"></script>

    <!-- <script src="https://unpkg.com/leaflet@1.0.3/dist/leaflet.js" integrity="sha512-A7vV8IFfih/D732iSSKi20u/ooOfj/AGehOKq0f4vLT1Zr2Y+RX7C+w8A1gaSasGtRUZpF/NZgzSAu4/Gc41Lg==" crossorigin=""></script>-->
    <script src="/leaflet.js"  crossorigin=""></script>

    <!-- // <script src="https://code.jquery.com/jquery-3.2.1.min.js" integrity="sha256-hwg4gsxgFZhOsEEamdOYGBf13FyQuiTwlAQgxVSNgt4=" crossorigin="anonymous"></script> -->
    <script src="/jquery-ui.js"></script>

    <style>

      html, body {
        background-color: gray;
        height: 100%;
        margin:   0;
        padding:  0;
      }

      #map { 
        width: 100%; 
        height: 96%;
        margin:  0;
        padding: 0;
        z-index: 0;
      }

      .vertical-container {
        margin:   0;
        padding:  0;
        /*height:  4%;*/
        display: -webkit-flex;
        display:         flex;
        -webkit-align-items: center;
               align-items: center;
        -webkit-justify-content: center;
               justify-content: center;
      }

      #msg { 
        color: white;
        background-color: gray;
        margin:  0;
        padding: 0;
      }

      .image_type1 {
        height: 42px;
        width: 42px;
      }

      .image_type2 {
        height: 42px;
        width: 42px;
      }

      .image_type3 {
        height: 42px;
        width: 126px;
      }

    .overlay {
        height: 0%;
        width: 0%;
        position: fixed;
        z-index: 1;
        top: 0;
        left: 0;
        /*background-color: rgb(241,241,241);*/
        background-color: rgba(181,152,152, 0.8);
        overflow-x: hidden;
        transition: 1s;
        font-family: 'Lato', sans-serif;
    }

    .overlay-content {
        position: relative;
        top: 5%;
        width: 100%;
        text-align: center;
        margin-top: 30px;
        color: white;
        /*margin: 10px, 20px, 10px, 20px;*/
        /*padding: 20px 10px 20px 10px;*/
    }

    .overlay a {
        padding: 8px;
        text-decoration: none;
        /*font-size: 36px;*/
        color: #686868;
        /*display: block;*/
        transition: 0.1s;
    }

    .overlay a:hover, .overlay a:focus {
        color: #f1f1f1;
    }

    .overlay .closebtn {
        position: absolute;
        top: 20px;
        right: 45px;
        font-size: 60px;
    }

    @media screen and (max-height: 450px) {
      .overlay a {font-size: 20px}
      .overlay .closebtn {
        font-size: 40px;
        top: 15px;
        right: 35px;
      }
    }

    </style>
  </head> 
  <body><%= yield %></body>
</html>


@@ my_receiver
<pre id='my_receiver'></pre>

<script>

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

        // add marker popup informaiton and open popup window
        marker.bindPopup("<center>" + msg + "<br>Depth: " + depth + " km<br>UTC: " + time + "<center>").openPopup();

        // pan and zoom to new map (earthquake) location
        map.setView(L.latLng(latitudeY, longitudeX), 8);

        // $("#msg").text("");
        divText = "";

        $("#map").effect("shake", "times: 20");

      } else {
        if (trace) console.log(json);

        var count = json["usgs earthquake count"]

        if (count === 0) $("#msg").css('color', 'rgb(165,255,144)')
        else if (count < 6) $("#msg").css('color', 'yellow')
        else $("#msg").css('color', 'rgb(245,107,97)')

        var date = new Date();
        json['msg'] = date;

        divText = date + " === USGS Earthquake Count: " + json["usgs earthquake count"] + " (last " + json["in recent minutes"] + " minutes)"

      }
      $("#msg").text(divText);

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
    var attributionOSM = '&copy; <a href="http://osm.org/copyright">OpenStreetMap</a> contributors';

    var osm = L.tileLayer('https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png', {  
      attribution: attributionOSM,
      subdomains: ['a', 'b', 'c']
    });

    var map = L.map('map', {
      center: [latitude, longitude],
      zoom: zoom,
      layers: [osm]
    });

    // scalebar
    L.control.scale().addTo(map);

    L.Control.Help = L.Control.extend({
        onAdd: function(map) {

            var img = L.DomUtil.create('img');

            img.src = '/images/help1.png';
            img.addEventListener('click', function () {
              openNav();
              console.log("open nav...")
            })

            return img;
        },
    });

    L.control.help = function(opts) {
        return new L.Control.Help(opts);
    }

    L.control.help({ position: 'topright' }).addTo(map);

  });

  function openNav() {
      console.log("in openNav()...")
      document.getElementById("myNav").style.height = "100%";
      document.getElementById("myNav").style.width = "100%";
  }

  function closeNav() {
      document.getElementById("myNav").style.height = "0%";
      document.getElementById("myNav").style.width = "0%";
  }


</script>


  <div id="myNav" class="overlay" onclick="closeNav();">
    <a class="closebtn" onclick="closeNav();" style=cursor:pointer>&times;</a>
    <div class="overlay-content"><h1>Shake-Shake</h1>
    <img src="/images/earthquake.png" height="96" width="96">
    </br></br>Display the latest earthquake on a map based on USGS information.
    </br></br>Note that earthquake information is not necessarily instantaneous meanings an earthquake that occurred 10 minutes ago may only be available through the USGS in the last few minutes.
    </br></br>Server-Sent Events are used in this webapp to send earthquake information from the server to the client (one-way).  Please note that Server-Sent Events are not supported by IE/Edge at this writing. 
    </br></br>This website is hosted at<a href="https://www.heroku.com/" target="_blank" class="heroku_text">Heroku</a>using a free dyno.
    </br></br>This website is for demonstration purposes.  Thanks for visiting.
    </br></br><a style=color:yellow href="https://github.com/greghorne/push_sinatra" target="_blank">GitHub Repository</a>
    </br></br></br><a href="https://www.ruby-lang.org" target="_blank"><img src="/images/Ruby_logo.svg" class="image_type1"></a>
    &nbsp;&nbsp;<a href="https://www.javascript.com" target="_blank"><img src="/images/js2.png" class="image_type1"></a>
    &nbsp;&nbsp;<a href="https://earthquake.usgs.gov/fdsnws/event/1/" target="_blank"><img src="/images/usgs.jpg" class="image_type2"></a>
    &nbsp;&nbsp;<a href="http://leafletjs.com" target="_blank"><img src="/images/leaflet.png" class="image_type3"></a></div></div>  
  
  <div id='map'></div>
  <div class="vertical-container"><div id="msg"></div></div>


