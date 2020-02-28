const express = require("express");
const pilot = express();

require("dotenv").config();
pilot
  .get("/", (req, res) => res.send("Hello World"))
  .get("/health", (req, res) => res.send("Up"));
pilot.listen(80, () => console.log("Server ready"));
