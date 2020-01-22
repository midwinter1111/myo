/*
 * Created by midwinter on 2017/11/1.
 * 
 * This program is using UDP not websocket!
 */

import de.voidplus.myo.*;
import controlP5.*;

import java.io.IOException;
import java.io.BufferedReader;
import java.io.InputStream;
import java.io.PrintStream;
import java.io.InputStreamReader;
import java.io.OutputStreamWriter;
import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.ArrayList;
import java.net.HttpURLConnection;
import java.net.MalformedURLException;
import java.net.URL;

import hypermedia.net.*;

Myo myo;
ArrayList<ArrayList<Integer>> sensors;
ControlP5 cp5;
UDP udp;
int portNo = 9002;
String ipAddress = "192.168.63.169"; // SmartWatch
int SEND_BUFFER_SIZE = 4;
byte[] sendBuffer = new byte[SEND_BUFFER_SIZE];

boolean useGUI = false;
boolean useSpectram = false;
boolean useWebsocket = false;
boolean sendStart = false;
boolean paintMode = true;

String receivedText = "";
String sendingText  = "";

float start = 0;
float ptime = 0;
float stime = 0;

int red   = 0;
int green = 0;
int blue  = 0;

 //192.168.63.193 HCI_network_24

 class NetworkData{
  int code; // 4byte integer
  int id;   // 4byte integer
 }

 boolean flagReceived = false;
 NetworkData receiveBuffer;

void setup(){
  // Screen setup
  frameRate(60);
  size(800, 600);
  background(200);
  noFill();
  stroke(0);

  // Myo setup
  println("attempting connect to Myo...");
  myo = new Myo(this, true); // true, with EMG data
  sensors = new ArrayList<ArrayList<Integer>>();
  for(int i=0; i<8; i++){
    sensors.add(new ArrayList<Integer>());
  }

  // UDP setup
  udp = new UDP(this, portNo);
  udp.setBuffer(SEND_BUFFER_SIZE);
  udp.setReceiveHandler("received");
  //udp.listen(true);

  receiveBuffer = new NetworkData();
  receiveBuffer.code = receiveBuffer.id = 0;

  // GUI setup
  cp5 = new ControlP5(this);
  cp5.addButton("RawDataButton")
  .setPosition(695, 40)
  .setSize(100, 40);
  cp5.addButton("SpectramButton")
  .setPosition(695, 100)
  .setSize(100, 40);
  cp5.addButton("SendButton")
  .setPosition(695, 160)
  .setSize(100, 40);

  background(255);

  println("setup was done!");
}

String calcAverage(){
 int sum = 0;
 //String s = "";
 for(int ch=0; ch<8; ch++){
  sum = sum + Math.abs(sensors.get(ch).get(sensors.get(ch).size()-1)) * 5;
  //s = s +" " + String.valueOf(sensors.get(ch).get(0));
 }
 //println("sensor: "+s);
 return (String.valueOf(sum));
}

int calcAverageValue(){
 int sum = 0;
 //String s = "";
 for(int ch=0; ch<8; ch++){
   if(sensors.get(ch).size() > 0){
    sum = sum + Math.abs(sensors.get(ch).get(sensors.get(ch).size()-2)) * 5;
   }
 }
 return sum;
}

void draw(){

  stroke(red, green, blue);

  if(paintMode){
    if(mousePressed == true){
      line(mouseX, mouseY, pmouseX, pmouseY);
    }
  }

  if(useGUI){
    background(255);
    synchronized(this){
      for(int i=0; i<8; i++){
        if(!sensors.get(i).isEmpty()){
          beginShape();
          for(int j=0; j<sensors.get(i).size(); j++){
           vertex(j, sensors.get(i).get(j)+(i*50)+175); 
          }
          endShape();
        }
      }
    }
  }

  else if(useSpectram){
    background(255);
   synchronized(this){
    for(int ch=0; ch<8; ch++){
     pushStyle();
     fill(171, 1, 88, 100);
     rect(50+(ch*75), 400, 75, -calcRMS(sensors.get(ch), sensors.get(ch).size()-1*2));
     popStyle();
    }
   }
  }

}

// Calcuration of Route Mean Square(RMS) value.
float calcRMS(ArrayList<Integer> emgValue, int headOfData){
  float rmsValue=0;

  try {
    for(int i=0; i<300; i++){
      rmsValue += pow(emgValue.get(headOfData-i), 2);
    }
  } catch(ArrayIndexOutOfBoundsException e){
    // println("ERROR:" + e + ", return value 0.");
    return 0.0;
  }
  return sqrt(rmsValue/5.0);
}


void RawDataButton(){
  useGUI = !useGUI;
  useSpectram = false;
  background(255);
}

void SpectramButton(){
  useGUI = false;
  useSpectram = !useSpectram;
  background(255);
}

void SendButton(){
  sendStart = !sendStart;
  //wss.sendMessage("");
  if(sendStart){
    println("send start!"); 
    (new Thread(new UDPThread())).start();
  }
  else{
    println("send suspended"); 
  }
}

void myoOnEmgData(Device myo, long timestamp, int[] data) {

  // Data:
  synchronized (this) {
    for (int i = 0; i<data.length; i++) {
      sensors.get(i).add((int) map(data[i], -128, 127, -25, 25)); // [-128 - 127]
    }
    while (sensors.get(0).size() > width) {
      for(ArrayList<Integer> sensor : sensors) {
        sensor.remove(0);
      }
    }
  }
}

int byteArrayToInt(byte[] b) {
  return b[3] & 0xFF | (b[2] & 0xFF) << 8 | (b[1] & 0xFF) << 16 | (b[0] & 0xFF) << 24;
}

byte[] intToByteArray(int a){
  byte[] bytes = ByteBuffer.allocate(4).putInt(a).array();
  return bytes;
}

class UDPThread implements Runnable{
  @Override
  public void run(){
    while(true){

      int emgData = calcAverageValue();

      byte[] tmpArray = intToByteArray(emgData);
      sendBuffer[0] = tmpArray[0];
      sendBuffer[1] = tmpArray[1];
      sendBuffer[2] = tmpArray[2];
      sendBuffer[3] = tmpArray[3];
      println(sendBuffer[0]+" "+sendBuffer[1]+" "+sendBuffer[2]+" "+sendBuffer[3]);

      udp.send(sendBuffer, ipAddress, portNo);

      try{
        Thread.sleep(20);
      }
      catch(Exception e){

      }
    }
  }
}
