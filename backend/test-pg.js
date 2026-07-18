const { Client } = require('pg');
const client = new Client('postgresql://postgres:123@localhost:5432/apora');
client.connect().then(async () => {
  try {
    const res = await client.query('SELECT unnest($1::int[]), $2::text, $3::text', [[1, 2], 'Title', 'Body']);
    console.log(res.rows);
  } catch (e) {
    console.error(e);
  } finally {
    client.end();
  }
});
