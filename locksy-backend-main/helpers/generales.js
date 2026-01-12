const mail = require("./mailCtrl");
const fs = require("fs");
var mysql = require("mysql2");
var mysqlConnection = mysql.createConnection({
  host: process.env.MYSQL_HOST || "127.0.0.1",
  port: process.env.MYSQL_PORT || "3306",
  user: process.env.MYSQL_USER || "pms",
  //password : 'aqw2000@',
  password: process.env.MYSQL_PASSWORD || "password",
  database: process.env.MYSQL_DATABASE || "pms",
  // host: 'cliniapp.net',
  // port: '3336',
  // user: 'pmsApp',
  // password: '.Clubtech*2021sas',
  // database: 'pms'
});
console.log("here         =============== DB SQL ===========");

// Connect with error handling - don't crash if connection fails
mysqlConnection.connect((err) => {
  if (err) {
    console.warn("MySQL connection failed:", err.message);
    console.warn("Email logging to MySQL will be disabled. Server will continue.");
  } else {
    console.log("MySQL connected for email logging");
    console.log("here         =============== DB SQL 111111 ===========");
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

const guardarMail = (
  from,
  to,
  subject,
  message,
  adjunto = null,
  adjunto2 = null,
  error = null,
  fecha_envio = null
) => {
  let res = false;
  let sql =
    "INSERT INTO correo_electronico(de, para, subject, message) " +
    "VALUES('" +
    from +
    "', '" +
    to +
    "', '" +
    subject +
    "', '" +
    message +
    "')";
  // console.log(sql)
  
  // Send email regardless of MySQL status
  mail.sendEmail({
    body: {
      from: from,
      to: to,
      subject: subject,
      text: message,
    },
  });
  
  // Try to log to MySQL, but don't fail if it's not available
  if (mysqlConnection && mysqlConnection.state !== 'disconnected') {
    mysqlConnection.query(sql, function (error, results, fields) {
      if (error) {
        console.warn("MySQL insert error:", error.message);
      } else {
        res = results.insertId;
      }
    });
  } else {
    console.warn("MySQL not available - email sent but not logged to database");
  }
  return res;
};

const guardarPreguntas = (
  id_usuario,
  pregunta1,
  respuesta1,
  pregunta2,
  respuesta2,
  pregunta3,
  respuesta3,
  pregunta4,
  respuesta4
) => {
  let res = false;
  var sql = "";

  sql =
    " INSERT INTO preguntas_usuario(id_usuario, pregunta1, respuesta1, pregunta2, respuesta2, pregunta3, respuesta3, pregunta4, respuesta4) " +
    " VALUES('" +
    id_usuario +
    "', '" +
    pregunta1 +
    "', '" +
    respuesta1 +
    "', '" +
    pregunta2 +
    "', '" +
    respuesta2 +
    "', '" +
    pregunta3 +
    "', '" +
    respuesta3 +
    "', '" +
    pregunta4 +
    "', '" +
    respuesta4 +
    "')" +
    " ON DUPLICATE KEY UPDATE " +
    " pregunta1='" +
    pregunta1 +
    "', respuesta1='" +
    respuesta1 +
    "', pregunta2='" +
    pregunta2 +
    "', respuesta2='" +
    respuesta2 +
    "', pregunta3='" +
    pregunta3 +
    "', respuesta3='" +
    respuesta3 +
    "', pregunta4='" +
    pregunta4 +
    "', respuesta4='" +
    respuesta4 +
    "'";

  // Check if MySQL connection is available before querying
  if (mysqlConnection && mysqlConnection.state !== 'disconnected') {
    mysqlConnection.query(sql, function (error, results, fields) {
      if (error) {
        console.warn("MySQL query error:", error.message);
        res = error;
      } else res = results.insertId;
    });
  } else {
    console.warn("MySQL not available - guardarPreguntas skipped");
    res = false;
  }
  return res;
};

const buscarSolicitudesCambioClave = (usuario) => {
  var res = false;
  var sql =
    "SELECT * FROM correo_electronico where para='" +
    usuario.email +
    "' and date(fecha_registro)=date(now()) and subject='Recuperar contraseña - ToolRay'";
  
  // Check if MySQL connection is available before querying
  if (mysqlConnection && mysqlConnection.state !== 'disconnected') {
    mysqlConnection.query(sql, function (error, results, fields) {
      if (error) {
        console.warn("MySQL query error:", error.message);
        return error;
      } else {
        return results;
      }
    });
  } else {
    console.warn("MySQL not available - buscarSolicitudesCambioClave skipped");
  }
  return res;
};

const buscarPreguntasUsuario = async (usuario, callback) => {
  var sql =
    "SELECT * FROM preguntas_usuario WHERE id_usuario='" + usuario + "'";
  
  // Check if MySQL connection is available before querying
  if (mysqlConnection && mysqlConnection.state !== 'disconnected') {
    mysqlConnection.query(sql, function (err, results) {
      if (err) {
        console.warn("MySQL query error:", err.message);
        return err;
      }
      return callback(results[0]);
    });
  } else {
    console.warn("MySQL not available - buscarPreguntasUsuario skipped");
    return callback(null);
  }
};

const insertReport = (tipo_solicitud, texto_solicitud, id_usuario, adjunto) => {
  let res = false;
  var sql =
    "INSERT INTO sop_solicitud(tipo_solicitud, texto_solicitud, id_usuario, adjunto) " +
    " VALUES('" +
    tipo_solicitud +
    "', '" +
    texto_solicitud +
    "', '" +
    id_usuario +
    "', '" +
    adjunto +
    "')";

  // Check if MySQL connection is available before querying
  if (mysqlConnection && mysqlConnection.state !== 'disconnected') {
    mysqlConnection.query(sql, function (error, results, fields) {
      if (error) {
        console.warn("MySQL query error:", error.message);
        res = error;
      } else res = results.insertId;
    });
  } else {
    console.warn("MySQL not available - insertReport skipped");
    res = false;
  }
  return res;
};

module.exports = {
  guardarMail,
  buscarSolicitudesCambioClave,
  buscarPreguntasUsuario,
  guardarPreguntas,
  insertReport,
};
