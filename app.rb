# coding: utf-8
require 'sinatra'
set server: 'thin', connections: []

# ================================================
get '/' do
  erb :my_receiver
end
# ================================================

# ================================================
get '/streamer', provides: 'text/event-stream' do

  stream :keep_open do |out|
    while true
      # out << "data: " + Time.now.to_s + "\n\n"
      lng = -96
      lat = 36
      location = "Tulsa, OK"
      data = "data: {\"lng\": " + lng.to_s + "}\n\n"
      # data = "data: {\"username\": \"bobby\", \"time\": \"02:33:48\"}\n\n"
      puts data
      out << data
      sleep 90
    end
  end
end
# ================================================

__END__

@@ layout
<html>
  <head> 
    <title>Shake-Shake</title> 
    <meta charset="utf-8" />
    <!-- // <script src="http://ajax.googleapis.com/ajax/libs/jquery/1/jquery.min.js"></script>  -->
  </head> 
  <body><%= yield %></body>
</html>



@@ my_receiver
<pre id='my_receiver'></pre>

<script>
  // reading
  console.log("In script...")

  var eventSource = new EventSource('/streamer');

  eventSource.addEventListener('message', function(event){
    // console.log("Receiving data!!!...")
    var data = JSON.parse(event.data);
    console.log(data.lng);
    // console.log(event.data)
    // alert("We be here")
  }, false);
</script>

<form>
  Waiting for messages in console...
</form>