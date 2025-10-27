import express from 'express';
import fs from 'fs';

const app = express();
const port = 8888;
app.get('/', (req, res) => {
    res.send('It works');
});

app.get('/txt', (req, res) => {
    const data = fs.readFileSync('links.txt', 'utf8');
    res.setHeader('content-type', 'text/plain');
    res.send(data);
});

app.listen(port, () => {
    console.log(`Server is running on port ${port}`);
})