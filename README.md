# push_sinatra
**Server-Sent Events**

*Study of HTML5 SSE*

- ruby 2.4.0p0 (2016-12-24 revision 57164) [i686-linux] 
- sinatra (1.4.8), sinatra-contrib (1.4.7)
- Leaflet 1.0.3 
</br>  

*What this website does...*

- Display to user a map.
- Server polls USGS every 30 seconds for earthquakes that have occured within the last 15 minutes.
- Note that the USGS information is not necessarily instantaneous meaning for example an earthquake that occurred 10 minutes ago might only be reported by the USGS within the last few minutes.
- The intent of the webpage is to display the last earthquake that has occurred.
- When a new earthquake event is received by the server, such inforrmation is pushed to the client browser repositioning the and displaying some information about the event.
</br>
This can be more fun than watching paint dry.</br>

Deployment: https://shake-shake.herokuapp.com/</br>

