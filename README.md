# push_sinatra
**Server-Sent Events**

*Study of HTML5 SSE*</br>

- The purpose of this project is to implement Server-Sent Events which is a server to client communication connection (one-way).  Explore web-sockets if 2-way communication is needed.  Please note that Server-Sent Events are not supported my IE/Edge.

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
- If the initial map displayed is a view of the USA with no marker on the map signifying an earthquake, this means an earthquake has not been recorded in the last 15 minutes.  Thus just leave the webpage as is and wait.
</br>
This can be more fun than watching paint dry.</br>
</br>
Deployment: https://shake-shake.herokuapp.com/</br>

