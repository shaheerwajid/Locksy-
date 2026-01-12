var mysql = require("mysql2");

var mysqlConnection = mysql.createConnection({
  host: process.env.MYSQL_HOST || "localhost",
  port: process.env.MYSQL_PORT || "3306",
  user: process.env.MYSQL_USER || "root",
  password: process.env.MYSQL_PASSWORD || "password",
  database: process.env.MYSQL_DATABASE || "pms",
});

module.exports = {
  mysqlConnection,
};

console.log("here         =============== DB SQL ===========");

// Connect with error handling - don't crash if connection fails
mysqlConnection.connect((err) => {
  if (err) {
    console.warn("MySQL connection failed:", err.message);
    console.warn("Server will continue without MySQL. MySQL features will be disabled.");
  } else {
    console.log("MySQL connected successfully");
    console.log("here         =============== DB SQL ===========");

    // Test query
    mysqlConnection.query(
      "SELECT 1 + 1 AS solution",
      function (error, results, fields) {
        if (error) {
          console.warn("MySQL test query failed:", error.message);
        } else {
          console.log("The solution is: ", results[0].solution);
        }
      }
    );
  }
});

// Handle connection errors gracefully
mysqlConnection.on('error', (err) => {
  if (err.code === 'PROTOCOL_CONNECTION_LOST') {
    console.warn("MySQL connection lost. Will attempt to reconnect when needed.");
  } else if (err.code === 'ECONNREFUSED') {
    console.warn("MySQL connection refused. Server will continue without MySQL.");
  } else {
    console.warn("MySQL error:", err.message);
  }
});
