const express = require("express");
const pilot = express();

require("dotenv").config();
pilot.get("/", (req, res) => res.send("Hello World!"));
pilot.listen(3000, () => console.log("Server ready"));
