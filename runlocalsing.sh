cd zookeeper-kafka &
ls &
chmod u+x $(pwd)/zookeeper-kafka/startzk.sh &
ls &
.$(pwd)/zookeeper-kafka/startzk.sh &
chmod u+x startkaf.sh &
./startkaf.sh &
cd .. &
cd producer &
chmod u+x build.sh &
./build.sh &
chmod u+x start.sh &
cd .. &
cd consumer &
chmod u+x build.sh &
./build.sh &
chmod u+x start.sh & 
./start.sh

