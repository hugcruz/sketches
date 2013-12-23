import ddf.minim.analysis.*;
import ddf.minim.*;
import ddf.minim.effects.*;

Minim minim;
AudioPlayer player;
FFT fft;
FFT fftWave;
AudioMetaData meta;

boolean isPlaying;
PImage imgPlay;
PImage imgPause;
PImage imgStop;

float[] buffer;

int BANDS_PER_OCTAVE = 4;
int BASE_FREQUENCY = 30;
int MARGIN = 20;

/*********/
/* Setup */
/*********/
void setup() {
  //setup screen
  size(1300, 750);
  rectMode(CORNER);
  background(0);
  
  //setup sound
  minim = new Minim(this);
  player = minim.loadFile("example1.mp3");
  
  //setup FFT object for analysis
  fft = new FFT(player.bufferSize(), player.sampleRate());
  fftWave = new FFT(player.bufferSize(), player.sampleRate());
  //log averages between BASE_FREQUENCY and sampleRate/2 splitting each octave in BANDS_PER_OCTAVE
  fft.logAverages(BASE_FREQUENCY, BANDS_PER_OCTAVE);
  //using window to reduce noise
  fft.window(FFT.HAMMING);
  
  //setup commands
  imgPlay = loadImage("play.png");
  imgPause = loadImage("pause.png");
  imgStop = loadImage("stop.png");
  
  //get metadata from mp3
  meta = player.getMetaData();
}


/********/
/* Draw */
/********/
void draw() {
  background(0);
  fill(255);
  
  drawControls();
  drawMetadata();
  
  if(isPlaying){
    fft.forward(player.mix);
    drawBeat();
  }

  drawColumns();
  drawProgress();
  
  if(isPlaying){
    drawWave();
  }
  
  //Stop player at end of track
  if(((int)player.position()/1000)==((int)player.length()/1000)){
    player.pause();
    player.rewind();
  }
}

void drawControls(){
  textSize(18);
  image(imgPlay, 30, MARGIN);
  text("PLAY", 68, MARGIN+23);
  image(imgPause, 120, MARGIN);
  text("PAUSE", 158, MARGIN+23);
  image(imgStop, 220, MARGIN);
  text("STOP", 258, MARGIN+23);
}

void drawMetadata(){
  fill(255);
  int textSize = 16;
  int marginLeft = 30;
  int marginTop = 150;
  textSize(textSize);
  text("File Name: " + meta.fileName(), marginLeft, marginTop);
  text("Title: " + meta.title(), marginLeft, marginTop+textSize);
  text("Author: " + meta.author(), marginLeft, marginTop+textSize*2); 
  text("Album: " + meta.album(), marginLeft, marginTop+textSize*3);
}

void drawProgress(){
  fill(220,220,220);
  //map player position to the progress bar length
  int currentProgress = (int)map(player.position(), 0, player.length(), 0, width/2-110);
  rect(width/2, MARGIN, currentProgress, 32);
  
  //show remaining progress
  fill(100,100,100);
  rect(width/2+currentProgress, MARGIN, map(player.length() - player.position(), 0, player.length(), 0, width/2-110), 32);
  
  //show textual information for current track progress
  fill(255,255,255);
  textSize(18);
  int minutes = (int)player.position()/60000;
  int seconds = (int)(player.position()-minutes*60000)/1000;
  String leadMinutes = minutes<10?"0"+minutes:""+minutes;
  String leadSeconds = seconds<10?"0"+seconds:""+seconds;
  text(leadMinutes+":"+leadSeconds, width/2-60, MARGIN+23);
  
  //show textual information for total track time
  int totalMinutes = (int)player.length()/60000;
  int totalSeconds = (int)(player.length()-totalMinutes*60000)/1000;
  String totalLeadMinutes = totalMinutes<10?"0"+totalMinutes:""+totalMinutes;
  String totalLeadSeconds = totalSeconds<10?"0"+totalSeconds:""+totalSeconds;
  text(totalLeadMinutes+":"+totalLeadSeconds, width-100, MARGIN+23);
}

void drawWave() {
  fill(0,255,0);
  stroke(255,255,0);
  
  //draw each point in the player buffer
  for (int i = 0; i < player.bufferSize() - 1; ++i) {
    float x1 = map(i, 0, player.bufferSize(), 50, width-50);
    float x2 = map(i+1, 0, player.bufferSize(), 50, width-50);
    line(x1, height - BANDS_PER_OCTAVE*15-20 - player.mix.get(i)*50 - 80, x2, height - BANDS_PER_OCTAVE*15-20 - player.mix.get(i+1)*50 - 80);
  }
  stroke(0);
}

void drawBeat() {
  //Bass drum (90-100Hz)
  if(fft.calcAvg(90, 100) > 80) {
    fill(255,0,0);
    ellipse(width-100-400, height/2-150, 100, 100);
  }
  
  //Snare drum (280-480Hz)
  if(fft.calcAvg(280, 480) > 15) {
    fill(0,255,0);
    ellipse(width-100-250, height/2-150, 100, 100);
  }
  
  //Cymbals (3640-15360Hz)
  if(fft.calcAvg(3640, 15360) > 0.5) {
    fill(0,0,255);
    ellipse(width-100-100, height/2-150, 100, 100);
  }
}

void drawColumns() {
  float freq = 0;
  
  int columnWidth = (width-100)/fft.avgSize();
  
  //show one column for each frequency band
  for(int i=0; i<fft.avgSize();++i){
    //determine base frequency
    freq = BASE_FREQUENCY * pow(2, (int)i/BANDS_PER_OCTAVE) + (i%BANDS_PER_OCTAVE) * BASE_FREQUENCY * pow(2, (int)i/BANDS_PER_OCTAVE)/BANDS_PER_OCTAVE;
    //determine color from index
    fill(map(fft.avgSize()-i, 0,fft.avgSize(),0,255),0,map(i, 0,fft.avgSize(),0,255));
    if(isPlaying){
      rect(MARGIN + i*columnWidth, height - BANDS_PER_OCTAVE*15-20 - 80, columnWidth, map(fft.getAvg(i)*freq/player.sampleRate(), 0, 1, 0, height/2)*-1);
    }
    
    //show labels
    textSize(8);
    text(freq+"Hz", 50 + i*columnWidth, height - BANDS_PER_OCTAVE*15 + i%BANDS_PER_OCTAVE*15 - 80);
  }
}


/*********************/
/* Mouse Interaction */
/*********************/
void mousePressed() {
  if(pressedPlay()) {
    isPlaying=true;
  }
  
  if(pressedPause()) {
    isPlaying=!isPlaying;
  }
  
  if(pressedStop()) {
    isPlaying=false;
    player.rewind();
  }
  
  if(pressedProgress()) {
    player.cue(getNewCue());
  }
  
  if(isPlaying){
    player.play();
  } else {
    player.pause();
  }
}

boolean pressedPlay(){
  return mouseX > 30 && mouseX < 30+32 && mouseY > MARGIN && mouseY < MARGIN+32;
}

boolean pressedPause(){
  return mouseX > 120 && mouseX < 120+32 && mouseY > MARGIN && mouseY < MARGIN+32;
}

boolean pressedStop(){
  return mouseX > 220 && mouseX < 220+32 && mouseY > MARGIN && mouseY < MARGIN+32;
}

boolean pressedProgress(){
  return mouseX > width/2 && mouseX < width-110 && mouseY > MARGIN && mouseY < MARGIN+32;
}

/**
* Return miliseconds for mouse click on the progress bar
**/
int getNewCue(){
  return (int)map(mouseX, width/2, width-110, 0, player.length());
}

/*******/
/* End */
/*******/
void stop()
{
  player.close();
  minim.stop();
  super.stop();
}
