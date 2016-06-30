using Toybox.Application as App;
using Toybox.WatchUi as Ui;
using Toybox.System as Sys;
using Toybox.Lang as Lang;
using Toybox.Math as Math;
using Toybox.System as System;

class TrendPaceView extends Ui.SimpleDataField {

    var appName=App.getApp().getProperty("appName");
    var version=App.getApp().getProperty("appVersion");
    var build="201604281754";

    var trimmedAverage=App.getApp().getProperty("trimmedAverage");

    // Set to true for debug messages
    var debug=App.getApp().getProperty("debug");

    const   DEBUG_OFF=0;
    const   DEBUG_MIN=1;
    const   DEBUG_MAX=2;

    // Average pace is calculated over a period of 30s
    var averagePeriod=App.getApp().getProperty("averageTimePeriod");
    var averageSArray = new[averagePeriod];
    var averageDDArray = new[averagePeriod];
    var averageDArray = new[averagePeriod];

    // Trend is shown by comparing a 10s pace against the 30s pace
    var trendPeriod=App.getApp().getProperty("trendTimePeriod");
    var trendSArray = new[trendPeriod];
    var trendDDArray = new[trendPeriod];
    var trendDArray = new[trendPeriod];

    var averageIndex=0;
    var trendIndex=0;

    var averageReadings=0;
    var trendReadings=0;

    var previousDistance=0;

    var paceMethod=App.getApp().getProperty("paceMethod");

    const   PACE_SPEED=0;
    const   PACE_DELTADISTANCE=1;
    const   PACE_DISTANCE=2;

    //! Set the label of the data field here.
    function initialize() {
        SimpleDataField.initialize();

        label = averagePeriod + "s trend pace";

        if( debug ) {
            Sys.println( appName + " (v" + version + ", " + build + ")");
        }

        if( debug == DEBUG_MIN ) {
            Sys.println( "\"Elapsed time\",\"Current pace\",\"Distance\",\"Average pace (speed)\",\"Average pace (delta distance)\",\"Average pace (distance)\",\"Trend pace (speed)\",\"Trend pace (delta distance)\",\"Trend pace (distance)\"");
        }
        if( debug == DEBUG_MAX) {
            Sys.println( "\"Elapsed time\",\"Current pace\",\"Distance\",\"Average pace (speed)\",\"Average pace (delta distance)\",\"Average pace (distance)\",\"Trend pace (speed)\",\"Trend pace (delta distance)\",\"Trend pace (distance)\",\"Current speed\",\"Average index\",\"Average readings\",\"Trend index\",\"Trend readings\",\"averageSArray\",\"trendSArray\",\"averageDDArray\",\"trendDDArray\",\"averageDArray\",\"trendDArray\"");
        }
    }

    // Print pace as min:sec
    function printPace(pace) {
        var paceStr;

        if( pace != null && ( pace instanceof Toybox.Lang.Number || pace instanceof Toybox.Lang.Float ) ) {
            paceStr=pace.format("%.2f");
            return paceStr.substring(0,paceStr.find(".")) + ":" + paceStr.substring(paceStr.find(".")+1,paceStr.find(".")+3);
        } else {
            return "--:--";
        }
    }

    // Convert from speed to pace (from m/s to min/km)
    function speedToPace(speed) {
        var seconds;

        if( speed==0.0 ) {
            return 0.0;
        }

        // Change from speed (m/s) to pace (min/km or min/mi)
        // Check device settings to get unit settings
        if( System.getDeviceSettings().paceUnits==System.UNIT_STATUTE ) {
            speed=1/speed*1609.344/60;
        } else {
            speed=1/speed*1000/60;
        }

        // Change decimals from base 100 to base 60 (a pace of 5.5 should be 5 minutes and 30 seconds)
        seconds=(speed-speed.toNumber())*60/100;
        if( seconds >= 0.595 ) {
            seconds=0;
            speed++;
        }

        return speed.toNumber()+seconds;
    }

    // Get average of an array (float)
    function getArrayAverage(arr, size) {
        var z=0.0;
        var avg=0.0;
        var high=0.0;
        var low=1.7*Math.pow(10,38);

        if( size == 0 ) {
            return 0.0;
        }

        // Calculate the array average and keep track of highest and lowest values
        for( var i=0; i<size; i++ ) {
            if(arr[i] != null ) {
                z=arr[i];
            } else {
                z=0;
            }

            avg=avg+z;

            if( z > high ) {
                high=z;
            }

            if( z < low ) {
                low=z;
            }
        }

        // Remove highest and lowest if the array size is 10 or more
        if( trimmedAverage && size >=4 ) {
            return ((avg-high)-low)/(size-2);
        }
        else {
            avg=avg/size;
        }

        return avg;
    }

    function compute(info) {
        var averageSPace=0.0;
        var trendSPace=0.0;
        var averageDDPace=0.0;
        var trendDDPace=0.0;
        var averageDPace=0.0;
        var trendDPace=0.0;
        var currentPace=0.0;
        var trendS="";
        var trendDD="";
        var trendD="";

        if( info.elapsedTime == null || info.currentSpeed == null || info.elapsedTime == 0 ) {
            return "--";
        }

        // paceMethod == PACE_DELTADISTANCE, Average of every delta distance during time period
        if( debug || paceMethod == PACE_DELTADISTANCE ) {
            averageDDArray[averageIndex]=info.elapsedDistance-previousDistance;
            trendDDArray[trendIndex]=info.elapsedDistance-previousDistance;
            previousDistance=info.elapsedDistance;
        }

        // paceMethod == PACE_DISTANCE, Total distance over time period
        if( debug || paceMethod == PACE_DISTANCE ) {
            averageDArray[averageIndex]=info.elapsedDistance;
            trendDArray[trendIndex]=info.elapsedDistance;
        }

        // paceMethod == PACE_SPEED, Average of every single speed reading during time period
        if( debug || paceMethod == PACE_SPEED ) {
            averageSArray[averageIndex]=info.currentSpeed;
            trendSArray[trendIndex]=info.currentSpeed;
        }

        // Increase readings until period reached
        if( trendReadings < trendPeriod ) {
            trendReadings++;
        }

        if( averageReadings < averagePeriod ) {
            averageReadings++;
        }

        // Get the average
        // paceMethod == PACE_DISTANCE
        if( debug || paceMethod == PACE_DISTANCE ) {
            if( averageReadings == averagePeriod ) {
                if( averageIndex < (averagePeriod-1) ) {
                    averageDPace=averageDArray[averageIndex]-averageDArray[averageIndex+1];
                } else {
                    averageDPace=averageDArray[averageIndex]-averageDArray[0];
                }

                if( trendIndex < (trendPeriod-1) ) {
                    trendDPace=trendDArray[trendIndex]-trendDArray[trendIndex+1];
                } else {
                    trendDPace=trendDArray[trendIndex]-trendDArray[0];
                }

                averageDPace=averageDPace/averageReadings;
                trendDPace=trendDPace/trendReadings;
            }
        }

        // paceMethod == PACE_SPEED
        if( debug || paceMethod == PACE_SPEED ) {
            averageSPace=getArrayAverage(averageSArray,averageReadings);
            trendSPace=getArrayAverage(trendSArray,trendReadings);
        }

        // paceMethod == PACE_DELTADISTANCE
        if( debug || paceMethod == PACE_DELTADISTANCE ) {
            averageDDPace=getArrayAverage(averageDDArray,averageReadings);
            trendDDPace=getArrayAverage(trendDDArray,trendReadings);
        }

        // Increment index
        averageIndex++;
        trendIndex++;

        // Cycle index
        if( averageIndex == averagePeriod ) {
            averageIndex=0;
        }

        if( trendIndex == trendPeriod ) {
            trendIndex=0;
        }

        // Convert from speed to pace (from m/s to min/km)
        if( debug || paceMethod == PACE_SPEED ) {
            averageSPace=speedToPace(averageSPace);
            trendSPace=speedToPace(trendSPace);

            if( trendSPace > averageSPace*1.1 ) {
               trendS="/";
            } else if( trendSPace > averageSPace ) {
                trendS="-";
            } else if( trendSPace < averageSPace*0.9 ) {
                trendS="*";
            } else if( trendSPace < averageSPace ) {
                trendS="+";
            } else {
                trendS="=";
            }
        }

        if( debug || paceMethod == PACE_DELTADISTANCE ) {
            averageDDPace=speedToPace(averageDDPace);
            trendDDPace=speedToPace(trendDDPace);

            if( trendDDPace > averageDDPace*1.1 ) {
                trendDD="/";
            } else if( trendDDPace > averageDDPace ) {
                trendDD="-";
            } else if( trendDDPace < averageDDPace*0.9 ) {
                trendDD="*";
            } else if( trendDDPace < averageDDPace ) {
                trendDD="+";
            } else {
                trendDD="=";
            }
        }

        if( debug || paceMethod == PACE_DISTANCE ) {
            averageDPace=speedToPace(averageDPace);
            trendDPace=speedToPace(trendDPace);

            if( trendDPace > averageDPace*1.1 ) {
                trendD="/";
            } else if( trendDPace > averageDPace ) {
                trendD="-";
            } else if( trendDPace < averageDPace*0.9 ) {
                trendD="*";
            } else if( trendDPace < averageDPace ) {
                trendD="+";
            } else {
                trendD="=";
            }
        }


        if( debug == DEBUG_MIN ) {
            currentPace=speedToPace(info.currentSpeed);
            Sys.println( "\"" + info.elapsedTime + "\",\"" + printPace(currentPace) + "\",\"" + info.elapsedDistance + "\",\"" + printPace(averageSPace) + trendS + "\",\"" + printPace(averageDDPace) + trendDD + "\",\"" + printPace(averageDPace) + trendD + "\",\"" + printPace(trendSPace) + "\",\"" + printPace(trendDDPace) + "\",\"" + printPace(trendDPace) + "\"");
        }
        if( debug == DEBUG_MAX) {
            currentPace=speedToPace(info.currentSpeed);
            Sys.print( "\"" + info.elapsedTime + "\",\"" + printPace(currentPace) + "\",\"" + info.elapsedDistance + "\",\"" + printPace(averageSPace) + trendS + "\",\"" + printPace(averageDDPace) + trendDD + "\",\"" + printPace(averageDPace) + trendD + "\",\"" + printPace(trendSPace) + "\",\"" + printPace(trendDDPace) + "\",\"" + printPace(trendDPace) + "\"");
            Sys.println( ",\"" + info.currentSpeed + "\",\"" + averageIndex + "\",\"" + averageReadings + "\",\"" + trendIndex + "\",\"" + trendReadings + "\",\"" + averageSArray.toString() + "\",\"" + trendSArray.toString() + "\",\"" + averageDDArray.toString() + "\",\"" + trendDDArray.toString() + "\",\"" + averageDArray.toString() + "\",\"" + trendDArray.toString() + "\"");
        }

        if( paceMethod == PACE_DELTADISTANCE ) {
            return printPace(averageDDPace)+trendDD;
        } else if( paceMethod == PACE_DISTANCE ) {
            return printPace(averageDPace)+trendD;
        } else {
            return printPace(averageSPace)+trendS;
        }
    }
}