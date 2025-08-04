services:

  zookeeper:
    image: apachepulsar/pulsar:latest
    container_name: zookeeper
    restart: on-failure
    networks:
      - pulsar
    volumes:
      - ./data/zookeeper:/pulsar/data/zookeeper
    environment:
      - metadataStoreUrl=zk:zookeeper:2181
      - PULSAR_MEM=-Xms256m -Xmx256m -XX:MaxDirectMemorySize=256m
    command:
      - bash
      - -c
      - |
        bin/apply-config-from-env.py conf/zookeeper.conf && \
        bin/generate-zookeeper-config.sh conf/zookeeper.conf && \
        exec bin/pulsar zookeeper
    healthcheck:
      test: ["CMD", "bin/pulsar-zookeeper-ruok.sh"]
      interval: 10s
      timeout: 5s
      retries: 30
    deploy:
      resources:
        limits:
          memory: 512M
          cpus: '0.5'
        reservations:
          memory: 256M
          cpus: '0.25'

  pulsar-init:
    image: apachepulsar/pulsar:latest
    container_name: pulsar-init
    hostname: pulsar-init
    restart: on-failure
    networks:
      - pulsar
    environment:
      PULSAR_MEM: -Xms256m -Xmx512m
    deploy:
      resources:
        limits:
          memory: 1G
          cpus: '0.5'
    command: |
      bash -c "
        echo 'Initializing Pulsar cluster metadata...'
        bin/pulsar initialize-cluster-metadata 
        --cluster cluster-a 
        --zookeeper zookeeper:2181 
        --configuration-store zookeeper:2181 
        --web-service-url http://broker:8080 
        --broker-service-url pulsar://broker:6650
        echo 'Cluster initialization completed!'
      "
    depends_on:
      zookeeper:
        condition: service_healthy

  bookie:
    image: apachepulsar/pulsar:latest
    container_name: bookie
    restart: on-failure
    networks:
      - pulsar
    environment:
      clusterName: cluster-a
      zkServers: zookeeper:2181
      metadataServiceUri: metadata-store:zk:zookeeper:2181
      advertisedAddress: bookie
      BOOKIE_MEM: -Xms512m -Xmx512m -XX:MaxDirectMemorySize=256m
    volumes:
      - bookie-data:/pulsar/data/bookkeeper
    deploy:
      resources:
        limits:
          memory: 1G
          cpus: '1.0'
        reservations:
          memory: 512M
          cpus: '0.5'
    depends_on:
      zookeeper:
        condition: service_healthy
      pulsar-init:
        condition: service_completed_successfully
    command: bash -c "bin/apply-config-from-env.py conf/bookkeeper.conf && exec bin/pulsar bookie"

  broker:
    image: apachepulsar/pulsar:latest
    container_name: broker
    hostname: broker
    restart: on-failure
    networks:
      - pulsar
    environment:
      metadataStoreUrl: zk:zookeeper:2181
      zookeeperServers: zookeeper:2181
      clusterName: cluster-a
      managedLedgerDefaultEnsembleSize: 1
      managedLedgerDefaultWriteQuorum: 1
      managedLedgerDefaultAckQuorum: 1
      advertisedAddress: broker
      advertisedListeners: external:pulsar://broker:6650
      PULSAR_MEM: -Xms512m -Xmx512m -XX:MaxDirectMemorySize=256m
    ports:
      - "6650:6650"
      - "8080:8080"
    volumes:
      - broker-data:/pulsar/data
    deploy:
      resources:
        limits:
          memory: 1G
          cpus: '1.0'
        reservations:
          memory: 512M
          cpus: '0.5'
    depends_on:
      zookeeper:
        condition: service_healthy
      bookie:
        condition: service_started
    command: bash -c "bin/apply-config-from-env.py conf/broker.conf && exec bin/pulsar broker"
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:8080/admin/v2/brokers/health || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s

networks:
  pulsar:
    driver: bridge

volumes:
  zookeeper-data:
  bookie-data:
  broker-data:
