function cloneData(data) {
  if (!data || typeof data !== 'object') return data;
  const next = { ...data };
  for (const [key, value] of Object.entries(next)) {
    if (Array.isArray(value)) next[key] = value.slice();
  }
  return next;
}

class FakeDocSnapshot {
  constructor(ref, data) {
    this.ref = ref;
    this.id = ref.id;
    this._data = data ? cloneData(data) : undefined;
    this.exists = Boolean(data);
  }

  data() {
    return this.exists ? cloneData(this._data) : undefined;
  }

  get(field) {
    return this._data?.[field];
  }
}

class FakeDocRef {
  constructor(db, collectionName, id) {
    this._db = db;
    this._collectionName = collectionName;
    this.id = id;
  }

  _collection() {
    return this._db._collectionData(this._collectionName);
  }

  _setSync(data, options = {}) {
    const current = this._collection().get(this.id) || {};
    const next = options.merge ? { ...current, ...cloneData(data) } : cloneData(data);
    this._collection().set(this.id, next);
  }

  _deleteSync() {
    this._collection().delete(this.id);
  }

  async get() {
    return new FakeDocSnapshot(this, this._collection().get(this.id));
  }

  async set(data, options = {}) {
    this._setSync(data, options);
  }

  async delete() {
    this._deleteSync();
  }
}

class FakeCollectionRef {
  constructor(db, name) {
    this._db = db;
    this._name = name;
  }

  doc(id) {
    return new FakeDocRef(this._db, this._name, id);
  }

  orderBy(field, direction = 'asc') {
    return new FakeQuery(this._db, this._name, {
      orderField: field,
      direction,
    });
  }

  where(field, operator, value) {
    return new FakeQuery(this._db, this._name, {
      filters: [{ field, operator, value }],
    });
  }
}

class FakeQuery {
  constructor(
    db,
    collectionName,
    {
      orderField = null,
      direction = 'asc',
      limitCount = null,
      filters = [],
    } = {},
  ) {
    this._db = db;
    this._collectionName = collectionName;
    this._orderField = orderField;
    this._direction = direction;
    this._limitCount = limitCount;
    this._filters = filters;
  }

  limit(count) {
    return new FakeQuery(this._db, this._collectionName, {
      orderField: this._orderField,
      direction: this._direction,
      limitCount: count,
      filters: this._filters,
    });
  }

  async get() {
    let docs = Array.from(this._db._collectionData(this._collectionName).entries())
      .map(([id, data]) => new FakeDocSnapshot(
        new FakeDocRef(this._db, this._collectionName, id),
        data,
      ));
    for (const { field, operator, value } of this._filters) {
      if (operator !== '==') {
        throw new Error(`FakeFirestore does not support where ${operator}`);
      }
      docs = docs.filter((doc) => doc.get(field) === value);
    }
    if (this._orderField) {
      docs.sort((a, b) => {
        const av = a.get(this._orderField) ?? 0;
        const bv = b.get(this._orderField) ?? 0;
        const delta = av === bv ? a.id.localeCompare(b.id) : av - bv;
        return this._direction === 'desc' ? -delta : delta;
      });
    }
    return {
      docs: this._limitCount == null ? docs : docs.slice(0, this._limitCount),
    };
  }
}

class FakeBatch {
  constructor() {
    this._deletes = [];
  }

  delete(ref) {
    this._deletes.push(ref);
  }

  async commit() {
    for (const ref of this._deletes) ref._deleteSync();
  }
}

class FakeTransaction {
  async get(ref) {
    return ref.get();
  }

  set(ref, data, options = {}) {
    ref._setSync(data, options);
    return this;
  }

  delete(ref) {
    ref._deleteSync();
    return this;
  }
}

class FakeFirestore {
  constructor(seed = {}) {
    this._data = new Map();
    this.transactionCount = 0;
    for (const [collectionName, docs] of Object.entries(seed)) {
      const collection = this._collectionData(collectionName);
      for (const [id, data] of Object.entries(docs)) {
        collection.set(id, cloneData(data));
      }
    }
  }

  _collectionData(name) {
    if (!this._data.has(name)) this._data.set(name, new Map());
    return this._data.get(name);
  }

  collection(name) {
    return new FakeCollectionRef(this, name);
  }

  batch() {
    return new FakeBatch();
  }

  async runTransaction(fn) {
    this.transactionCount += 1;
    return fn(new FakeTransaction());
  }

  dump(collectionName, id) {
    return cloneData(this._collectionData(collectionName).get(id));
  }

  ids(collectionName) {
    return Array.from(this._collectionData(collectionName).keys()).sort();
  }
}

module.exports = { FakeFirestore };
