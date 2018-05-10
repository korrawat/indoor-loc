const express = require('express')
const bodyParser = require('body-parser');
const fs = require('fs');
const app = express()

var data = {"ibeacons": [], "pedometer": [], "accelerometer": [], "test": []};
var curr_id = 0;

const EXPORT_INTERVAL = 5 // in seconds

app.use(bodyParser.json());

var write_data_file = function(category, timestamp) {
  const EXPORT_DIR = "collected_data/";
  const filename = EXPORT_DIR + category + '/' + timestamp + ".json";
  const jsonData = JSON.stringify(data[category]);

  fs.writeFile(filename, jsonData, 'utf8', function(err) {
      if(err) {
          return console.log("ERROR Exporting to file: ", err);
      }
      console.log("Export " + category + " to the file: " + filename);
      // clean array
      data[category] = [];
  });

}

var export_data = function() {
  const timestamp = Date.now().toString();
  // write_data_file("test", timestamp);
  write_data_file("ibeacons", timestamp);
  write_data_file("pedometer", timestamp);
  write_data_file("accelerometer", timestamp);

}

setInterval(export_data, EXPORT_INTERVAL * 1000);

// Receive beacon data whenever we enter/exit a beacon's region
app.post('/ibeacons', function(request, response){
    var new_data = request.body;
    var ibeacons = new_data.ibeacons;
    //console.log("Receive new ibeacons data: ", ibeacons.length, "\t",  ibeacons);      // your JSON
    for (i in ibeacons) {
        data["ibeacons"].push(ibeacons[i]);
    }
    //console.log("ibeacons_data: ", ibeacons_data);
    response.send("Received!");    // echo the result back
});

// Receive beacon data whenever we enter/exit a beacon's region
app.post('/pedometer', function(request, response){
    var new_data = request.body;
    data["pedometer"].push(new_data);

    //console.log("Received pedometer data: ", request, new_data);
    response.send("Received!");    // echo the result back
});

// Receive beacon data whenever we enter/exit a beacon's region
app.post('/accelerometer', function(request, response){
    var new_data = request.body;
    var readings = new_data.readings;
    var heading = new_data.magneticHeading;

    for (r in readings) {
      data["accelerometer"].push(r)
    }

    //console.log("Receive new magnetometer data: ", request, new_data);      // your JSON
    response.send("Received!");    // echo the result back
});



app.listen(3000, () => console.log('Localization is listening on port 3000!'))
