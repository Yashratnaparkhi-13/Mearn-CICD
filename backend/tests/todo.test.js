const request = require('supertest');
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');

const app = require('../src/app');

let mongoServer;

beforeAll(async () => {
  mongoServer = await MongoMemoryServer.create();
  const uri = mongoServer.getUri();
  await mongoose.connect(uri);
});

afterEach(async () => {
  const collections = mongoose.connection.collections;
  // eslint-disable-next-line no-restricted-syntax
  for (const key of Object.keys(collections)) {
    // eslint-disable-next-line no-await-in-loop
    await collections[key].deleteMany({});
  }
});

afterAll(async () => {
  await mongoose.disconnect();
  await mongoServer.stop();
});

describe('Health endpoints', () => {
  it('GET /health returns status ok', async () => {
    const res = await request(app).get('/health');
    expect(res.statusCode).toBe(200);
    expect(res.body.status).toBe('ok');
  });

  it('GET /ready returns status ready', async () => {
    const res = await request(app).get('/ready');
    expect(res.statusCode).toBe(200);
    expect(res.body.status).toBe('ready');
  });
});

describe('Todo API', () => {
  it('GET /api/todos returns an empty array initially', async () => {
    const res = await request(app).get('/api/todos');
    expect(res.statusCode).toBe(200);
    expect(res.body).toEqual([]);
  });

  it('POST /api/todos creates a new todo', async () => {
    const res = await request(app)
      .post('/api/todos')
      .send({ title: 'Learn GitLab CI/CD' });
    expect(res.statusCode).toBe(201);
    expect(res.body.title).toBe('Learn GitLab CI/CD');
    expect(res.body.completed).toBe(false);
  });

  it('POST /api/todos fails when title is missing', async () => {
    const res = await request(app).post('/api/todos').send({});
    expect(res.statusCode).toBe(400);
  });

  it('PUT /api/todos/:id updates a todo', async () => {
    const created = await request(app)
      .post('/api/todos')
      .send({ title: 'Deploy to cloud' });

    const res = await request(app)
      .put(`/api/todos/${created.body._id}`)
      .send({ completed: true });

    expect(res.statusCode).toBe(200);
    expect(res.body.completed).toBe(true);
  });

  it('DELETE /api/todos/:id deletes a todo', async () => {
    const created = await request(app)
      .post('/api/todos')
      .send({ title: 'Set up blue-green deployment' });

    const res = await request(app).delete(`/api/todos/${created.body._id}`);
    expect(res.statusCode).toBe(200);

    const getRes = await request(app).get('/api/todos');
    expect(getRes.body.length).toBe(0);
  });

  it('returns 404 for a non-existent todo on update', async () => {
    const fakeId = new mongoose.Types.ObjectId();
    const res = await request(app)
      .put(`/api/todos/${fakeId}`)
      .send({ completed: true });
    expect(res.statusCode).toBe(404);
  });
});
