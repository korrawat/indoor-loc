const express = require('express')
const bodyParser = require('body-parser');
const fs = require('fs');
const app = express()

var ibeacons_data = [];
var curr_id = 0;

app.use(bodyParser.json());

var export_data = function() {
  const timestamp = Date.now();
  const filename = "collected_data/" + timestamp.toString() + ".json";
  const json = JSON.stringify(ibeacons_data);
  fs.writeFile(filename, json, 'utf8', function(err) {
      if(err) {
          return console.log("ERROR Exporting to file: ", err);
      }
      console.log("Export to the file: " + filename);
      ibeacons_data = [];
  });

}

setInterval(export_data, 10000);

app.post('/ibeacons', function(request, response){
    var new_data = request.body;
    // var ibeacons = JSON.parse(new_data.ibeacons);
    var ibeacons = new_data.ibeacons;
    console.log("Receive new ibeacons data: ", new_data.ibeacons, ibeacons, typeof(ibeacons));      // your JSON
    for (i in ibeacons) {
        ibeacons_data.push(ibeacons[i]);
    }
    // ibeacons_data = ibeacons_data.concat(ibeacons);
    console.log("ibeacons_data: ", ibeacons_data);
    response.send("Received!");    // echo the result back
});

app.get('/addpoint/:touchval', (req, res) => {
  var touchval = req.params.touchval;
  res.send("Added: " + touchval);
  console.log("Add point: ", touchval);
  touches.push([Number(touchval)]);
  curr_id ++;
  console.log("Points: ", touches);
})

app.get('/addpoints/:touchvals', (req, res) => {
  var touchvals = req.params.touchvals.split("-");
  touchvals = touchvals.map( val => Number(val));
  touches[curr_id] = touchvals;
  curr_id ++;
  res.send("Added: " + touchvals);
  console.log("Add points: ", touchvals);
  console.log(String(curr_id), "Points: ", touches);
})


app.get('/getpoint/:id', (req, res) => {
  var length = touches.length;
  var id = req.params.id;
  if (id >= length) {
    res.send("ERROR: Point ID NOT found!");
  } else {
    res.send(touches[id]);
  }
})


app.get('/getlatest', (req, res) => {
  if (curr_id <= 0) {
    res.send("NULL: No point added");
  } else {
    var result = "id = "+ String(curr_id - 1) +": " + touches[curr_id - 1];
    res.send(result);
  }
})

app.get('/getlatestid', (req, res) => {
    res.send(String(curr_id - 1));
})


app.listen(3000, () => console.log('Localization is listening on port 3000!'))
