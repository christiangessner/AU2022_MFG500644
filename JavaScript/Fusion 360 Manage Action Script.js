// Defining the payload data
var obj = {
    descriptor: item.key,
    number: item.NUMBER,
    title: item.TITLE,
    description: item.DESCRIPTION,
    owner: item.descriptor.ownerID,
    workspace: item.master.workspaceID,
    dmsID: item.master.dmsID
};

// Converting JS object to JSON string
var payload = JSON.stringify(obj, null, 2);

// Creating HTTP request
var request = new XMLHttpRequest();
request.withCredentials = false;

// Defining the method and endpoint
request.open("POST", "<CALLBACK_URL>");
//request.setRequestHeader("Authorization", "Bearer " + bearer.access_token);

// Defining the content type
request.setRequestHeader("Content-Type", "application/json");

// Send the request
request.send(payload);

// Print the response
println(request.responseText);