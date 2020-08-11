const mysql = require("mysql")

const connection = mysql.createConnection({
  user: "root",
  host: "localhost",
  password: "forchange",
})

connection.connect((err) => {
  if (err) {
    console.error("error connecting: " + err.stack)
    return
  }

  console.log(`connection start: ${connection.threadId}`)
})

connection.query("SELECT 1 + 1 AS solution", (err, rows, fields) => {
  if (err) throw err
  console.log("The rows:", rows)
})

connection.end((err) => {
  if (err) {
    console.error("error ending: " + err.stack)
    return
  }

  console.log(`connection end: ${connection.threadId}`)
})