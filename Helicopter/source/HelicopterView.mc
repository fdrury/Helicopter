using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;
using Toybox.Sensor;
using Toybox.Timer;
using Toybox.Math;
using Toybox.Position;
using Toybox.ActivityRecording;

//TODO: replace magic number 15 with height of icon and autoset based on icon (onDisplay?)

class HelicopterView extends Ui.View {
    var session = null;
    var baseElevation = null;
    var currentElevation = null;
    var playerScore = 0;
    var highScore = 0;
    //TODO: should be function of screen width
    var PIXELS_PER_TUNNEL_POINT = 60;
    var numTunnelPoints = 5; //set in onLayout
    var NUMBER_OF_TUNNEL_POINTS = 5; // MUST be ODD for collision algorithm
    var ELEVATION_SPREAD = 10.0;
    var tunnelWidth = 40;
    var tunnel = new[NUMBER_OF_TUNNEL_POINTS + 1];
    var tunnelPosition = 0;
    var tunnelTimer = new Timer.Timer();
    var screenTimer = new Timer.Timer();
    var helicopterIcon;
    var positionInfo = Position.getInfo();
    var accurateAtl = false;
    var insideTunnel = true;

    function initialize() {
        View.initialize();
        Position.enableLocationEvents(Position.LOCATION_CONTINUOUS, method(:onPosition));
        
        //seed random number generator
        
        
        baseElevation = positionInfo.altitude;
        currentElevation = baseElevation;
    }

    // Load your resources here
    function onLayout(dc) {
        setLayout(Rez.Layouts.MainLayout(dc));
        helicopterIcon = Ui.loadResource(Rez.Drawables.Helicopter);
        initializeTunnel(dc);
        tunnelTimer.start(method(:moveTunnel), 200, true);
        screenTimer.start(method(:updateScreen), 50, true);
        numTunnelPoints = (dc.getWidth() / PIXELS_PER_TUNNEL_POINT) / 2 * 2 + 1; //must be odd for collision algorithm
    }
    
    function onPosition(position){
        //TODO: integrate this method properly
    }

    // Called when this View is brought to the foreground. Restore
    // the state of this View and prepare it to be shown. This includes
    // loading resources into memory.
    function onShow() {
    }

    // Update the view
    function onUpdate(dc) {
        // Call the parent onUpdate function to redraw the layout
        View.onUpdate(dc);
        
        positionInfo = Position.getInfo();
        if(positionInfo.altitude == null){
            dc.setColor(Gfx.COLOR_RED, Gfx.COLOR_RED);
            dc.fillRectangle(0, 0, dc.getWidth(), dc.getHeight());
            dc.setColor(Gfx.COLOR_BLACK, Gfx.COLOR_TRANSPARENT);
            dc.drawText(dc.getWidth() / 2, dc.getHeight() / 2, Gfx.FONT_TINY, "DEVICE NOT SUPPORTED", Gfx.TEXT_JUSTIFY_CENTER);
        }
        else if(positionInfo.accuracy != Position.QUALITY_GOOD){
            dc.setColor(Gfx.COLOR_RED, Gfx.COLOR_RED);
            dc.fillRectangle(0, 0, dc.getWidth(), dc.getHeight());
            dc.setColor(Gfx.COLOR_BLACK, Gfx.COLOR_TRANSPARENT);
            dc.drawText(dc.getWidth() / 2, dc.getHeight() / 2 - Gfx.getFontHeight(Gfx.FONT_TINY), Gfx.FONT_TINY, "AWAITING GPS SIGNAL...", Gfx.TEXT_JUSTIFY_CENTER);
            
            dc.drawText(dc.getWidth() / 2, dc.getHeight() / 2, Gfx.FONT_XTINY, "PLEASE BE COURTEOUS\nAND AWARE OF YOUR\nSURROUNDINGS", Gfx.TEXT_JUSTIFY_CENTER);
        }
        else{
            if(!accurateAtl && positionInfo.altitude != null){
                baseElevation = positionInfo.altitude;
                currentElevation = baseElevation;
                accurateAtl = true;
            }
            checkInsideTunnel(dc);
            if(insideTunnel) {
                dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
            } else {
                dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_RED);
                playerScore = 0;
            }
            dc.clear();
            drawTunnel(dc);
            if(helicopterIcon != null){
                dc.drawBitmap(dc.getWidth() / 2 - 13, getHeliHeight(dc), helicopterIcon);
            }
            dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
            dc.drawText(10, dc.getHeight() / 2 - Graphics.getFontHeight(dc.FONT_MEDIUM) / 2, dc.FONT_MEDIUM, playerScore, Graphics.TEXT_JUSTIFY_LEFT);
            dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
            dc.drawText(dc.getWidth() - 10, dc.getHeight() / 2 - Graphics.getFontHeight(dc.FONT_MEDIUM) / 2, dc.FONT_MEDIUM, highScore, Graphics.TEXT_JUSTIFY_RIGHT);
        }
    }

    // Called when this View is removed from the screen. Save the
    // state of this View here. This includes freeing resources from
    // memory.
    function onHide() {
    }
    
    function initializeTunnel(dc){
        for(var i = 0; i < tunnel.size(); i += 1){
            tunnel[i] = dc.getHeight() - tunnelWidth / 2;
        }
    }
    
    // use the select Start/Stop or touch for recording
    function onSelect() {
       if(Toybox has :ActivityRecording) {                          // check device for activity recording
           if((session == null) || (session.isRecording() == false)) {
               session = ActivityRecording.createSession(           // set up recording session
                    {
                     :name=>"Helicopter Stair Running",             // set session name
                     :sport=>ActivityRecording.SPORT_RUNNING,       // set sport type
                     :subSport=>ActivityRecording.SUB_SPORT_GENERIC // set sub sport type
                    }
               );
               session.createField("Helicopter Score", "HELI".toNumber(), Field.DATA_TYPE_UINT_8, null);
               session.start();                                     // call start session
           }
           else if((session != null) && session.isRecording()) {
               session.stop();                                      // stop the session
               session.save();                                      // save the session
               session = null;                                      // set session control variable to null
           }
       }
       return true;                                                 // return true for onSelect function
    }
    
    function drawTunnel(dc){
        //set line width
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_WHITE);
        dc.setPenWidth(tunnelWidth);
        
        if(tunnelPosition >= getSegmentWidth(dc)){
            updateTunnel(dc);
            tunnelPosition = 0;
        }
        
        for(var i = 1; i < tunnel.size(); i += 1){
            dc.drawLine((i - 1) * getSegmentWidth(dc) - tunnelPosition, tunnel[i - 1], i * getSegmentWidth(dc) - tunnelPosition, tunnel[i]);
        }
    }
    
    function getSegmentWidth(dc){
        if(tunnel.size() == 1){
            //TODO: throw exception or something
            return -1;
        }
        return dc.getWidth() / (tunnel.size() - 2);
    }
    
    function updateTunnel(dc) {
        for(var i = 1; i < tunnel.size(); i += 1) {
            tunnel[i - 1] = tunnel[i];
        }
        tunnel[tunnel.size() - 1] = Math.rand() % (dc.getHeight() - tunnelWidth) + tunnelWidth / 2;
        
        if(insideTunnel) {
            playerScore += 1;
            if(playerScore > highScore) {
                highScore = playerScore;
            }
        }
    }
    
    function updateScreen() {
        Ui.requestUpdate();
    }
    
    function moveTunnel() {
        tunnelPosition += 1;
    }
    
    function getHeliHeight(dc) {
        positionInfo = Position.getInfo();
        if(positionInfo.altitude != null) {
            currentElevation = positionInfo.altitude;
        }
        if(currentElevation < baseElevation) {
            return dc.getHeight() - 15;
        }
        if(currentElevation > baseElevation + ELEVATION_SPREAD) {
            return 0;
        }
        return dc.getHeight() - 15 - (currentElevation - baseElevation) / ELEVATION_SPREAD * (dc.getHeight() - 15);
    }
    
    //TODO: check for null, divide by 0, etc.
    function checkInsideTunnel(dc) {
        var index1 = tunnel.size() / 2 - 1;
        var index2 = index1 + 1;
        var slope = (tunnel[index2] - tunnel[index1] + 0.0) / (index2 * getSegmentWidth(dc) - index1 * getSegmentWidth(dc) + 0.0);
        var intercept = tunnel[index1] - slope * (index1 * getSegmentWidth(dc) - tunnelPosition + 0.0);
        var tunnelHeight = slope * dc.getWidth() / 2 + intercept;
        var tunnelClearance = tunnelWidth * Math.sqrt(slope * slope + 1);
        
        //System.println("Heli height: " + getHeliHeight(dc) + "     tunnelHeight: " + tunnelHeight + "     slope: " + slope + "     intercept: " + intercept);
        
        //15 is half the heigth of the heli icon
        //8 is ~half the height of the heli icon
        if(getHeliHeight(dc) > tunnelHeight - tunnelClearance / 2 && getHeliHeight(dc) + 15 < tunnelHeight + tunnelClearance / 2) {
            insideTunnel = true;
        } else {
            insideTunnel = false;
        }
        /*if(getHeliHeight(dc) - tunnelHeight - 15 > tunnelWidth / 2 || tunnelHeight - getHeliHeight(dc) > tunnelWidth / 2 ) {
            insideTunnel = false;
        } else {
            insideTunnel = true;
        }*/
    }

}
