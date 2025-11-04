#!/bin/bash

echo "🚀 Starting MongoDB Sharded Cluster..."

# Build custom Mongo image
docker build -t mongo-cluster .

# Create isolated network
docker network create mongo-net 

# --- Start Config Servers ---
echo "🧱 Starting config servers..."
for i in 1 2 3; do
  docker run -d --name config${i} --net mongo-net mongo-cluster \
    mongod --configsvr --replSet configReplSet --port 27019 --dbpath /data/db
done

# Wait for configs to start
echo "⏳ Waiting for config servers to initialize..."
sleep 15

# --- Initialize Config Server Replica Set ---
echo "⚙️  Initiating config server replica set..."
docker exec -it config1 mongosh --eval '
rs.initiate({
  _id: "configReplSet",
  configsvr: true,
  members: [
    { _id: 0, host: "config1:27019" },
    { _id: 1, host: "config2:27019" },
    { _id: 2, host: "config3:27019" }
  ]
})'
sleep 10

# --- Start Shard1 Replica Set ---
echo "🧩 Starting Shard 1 replica set..."
for i in a b c; do
  docker run -d --name shard1${i} --net mongo-net mongo-cluster \
    mongod --shardsvr --replSet shard1ReplSet --port 27018 --dbpath /data/db
done
sleep 10

# --- Initialize Shard1 Replica Set ---
docker exec -it shard1a mongosh --eval '
rs.initiate({
  _id: "shard1ReplSet",
  members: [
    { _id: 0, host: "shard1a:27018" },
    { _id: 1, host: "shard1b:27018" },
    { _id: 2, host: "shard1c:27018" }
  ]
})'
sleep 10

# --- Start Shard2 Replica Set ---
echo "🧩 Starting Shard 2 replica set..."
for i in a b c; do
  docker run -d --name shard2${i} --net mongo-net mongo-cluster \
    mongod --shardsvr --replSet shard2ReplSet --port 27018 --dbpath /data/db
done
sleep 10

# --- Initialize Shard2 Replica Set ---
docker exec -it shard2a mongosh --eval '
rs.initiate({
  _id: "shard2ReplSet",
  members: [
    { _id: 0, host: "shard2a:27018" },
    { _id: 1, host: "shard2b:27018" },
    { _id: 2, host: "shard2c:27018" }
  ]
})'
sleep 10

# --- Start Router (mongos) ---
echo "🚪 Starting router (mongos)..."
docker run -d --name router --net mongo-net -p 27017:27017 mongo:6.0 \
  mongos --configdb configReplSet/config1:27019,config2:27019,config3:27019 --port 27017

sleep 10

# --- Add Shards via Router ---
echo "🔗 Adding shards to the cluster..."
docker exec -it router mongosh --eval '
sh.addShard("shard1ReplSet/shard1a:27018,shard1b:27018,shard1c:27018");
sh.addShard("shard2ReplSet/shard2a:27018,shard2b:27018,shard2c:27018");
'

echo "✅ MongoDB Sharded Cluster setup complete!"
echo "You can now connect using: mongodb://localhost:27017"
