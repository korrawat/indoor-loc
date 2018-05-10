const express = require('express')
const bodyParser = require('body-parser');
const fs = require('fs');
const app = express()
const mkdirp = require('mkdirp');

const EXPORT_INTERVAL = 3 // in seconds
const DEBUG = false;
const DEFAULT_EXPORT_DIR = "collected_data/";

var data = {"ibeacons": [], "pedometer": [], "accelerometer": []};
var curr_id = 0;
var current_dir = DEFAULT_EXPORT_DIR;

app.use(bodyParser.json());

var update_curr_dir = function(curr_label) {
  if(curr_label == '') {
    current_dir = DEFAULT_EXPORT_DIR;
    console.log("Update curr dir to default :", current_dir);
    return;
  }
  current_dir = DEFAULT_EXPORT_DIR + curr_label.toLowerCase().split(' ').join('_') + '/'
  console.log("Update curr dir to ", current_dir, " from label ", curr_label)
}

var write_data_file = function(dir_path, category, timestamp) {
  const filename = dir_path + category + '/' + timestamp + ".json";
  var jsonData;
  if (category == "all") {
    jsonData = JSON.stringify(data);
  } else {
    jsonData = JSON.stringify(data[category]);
  }

  fs.writeFile(filename, jsonData, 'utf8', function(err) {
      if(err) {
          return console.log("ERROR Exporting to file: ", err);
      }
      if (DEBUG) {
        console.log("Export " + category + " to the file: " + filename);
      }
      // clean array
      data[category] = [];
  });

}

var init_collection = function(dir_name, categories) {
  console.log("Creating a new collection ", dir_name, " ...")
  EXPORT_DIR = dir_name + '/'
  mkdirp(EXPORT_DIR, function(err) { 
    if(err) {
      console.log("Cannot create a collection dir: ", EXPORT_DIR)
    } else {
      console.log("Create a collection dir: ", EXPORT_DIR)
      for (i in categories) {
        const subdir_name = EXPORT_DIR + categories[i] + '/';
        mkdirp(subdir_name , function(err) { 
          if(err) {
            console.log("Cannot create a dir: ", subdir_name)
          } else {
            console.log("Create a dir: ", subdir_name)
          }
        });
      }
    }
  });
}

var export_data = function() {

  const timestamp = Date.now().toString();
  const data_categories = ["ibeacons", "pedometer", "accelerometer", "all"];

  if (!fs.existsSync(current_dir)){
    init_collection(current_dir, data_categories);
  }

  data_categories.forEach(function(category){
    write_data_file(current_dir, category, timestamp);
  });

  console.log("Export files: " + timestamp + ".json to " + data_categories.join(", "));
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
    update_curr_dir(new_data.label);
    response.send("Received!");    // echo the result back
});

// Receive beacon data whenever we enter/exit a beacon's region
app.post('/pedometer', function(request, response){
    var new_data = request.body;
    data["pedometer"].push(new_data);

    //console.log("Received pedometer data: ", request, new_data);
    update_curr_dir(new_data.label);
    response.send("Received!");    // echo the result back
});

// Receive beacon data whenever we enter/exit a beacon's region
app.post('/accelerometer', function(request, response){
    var new_data = request.body;
    console.log(new_data)

    for (i in new_data.data) {
      data["accelerometer"].push(new_data[i])
    }

    //console.log("Receive new magnetometer data: ", request, new_data);      // your JSON
    update_curr_dir(new_data.label);
    response.send("Received!");    // echo the result back
});



app.listen(3000, () => console.log('Localization is listening on port 3000!'))
