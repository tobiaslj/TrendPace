using Toybox.WatchUi as Ui;
using Toybox.System as Sys;
using Toybox.Lang as Lang;
using Toybox.Math as Math;
using Toybox.System as System;

class TrendPaceView extends Ui.SimpleDataField {

    var version="1.00";
    var build="201604281754";

    // Set to true for debug messages
    var debug=false;

    // Average pace is calculated over a period of 30s
    var averagePeriod=30;
    var averageArray = new[averagePeriod];

    // Trend is shown by comparing a 10s pace against the 30s pace
    var trendPeriod=10;
    var trendArray = new[trendPeriod];

    var averageIndex;
    var trendIndex;

    var averageReadings;
    var trendReadings;

    //! Set the label of the data field here.
    function initialize() {
        SimpleDataField.initialize();

        label = averagePeriod + "s trend pace";
        averageIndex=0;
        trendIndex=0;
        averageReadings=0;
        trendReadings=0;
    }

    // Convert from speed to pace (from m/s to min/km)
    function speedToPace(speed) {
        var minutes;
        var distance;

        if( speed==0.0 ) {
            return 0.0;
        }

        if( System.getDeviceSettings().paceUnits==System.UNIT_STATUTE ) {
            distance=1609.344;
        } else {
            distance=1000.0;
        }

        speed=1/speed*distance/60;

        // Change decimals from base 100 to base 60 (a pace of 5.5 should be 5 minutes and 30 seconds)
        minutes=(speed-speed.toNumber())*60/100;
        return speed.toNumber()+minutes;
    }

    // Get average of an array (float)
    function getArrayAverage(arr) {
        var z=0.0;
        var avg=0.0;
        var high=0.0;
        var low=1.7*Math.pow(10,38);

        if( arr.size() == 0 ) {
            return 0.0;
        }

        for( var i=0; i<arr.size(); i++ ) {
            z=arr[i];
            if( debug ) {
                Sys.println( "z               : " + z );
            }

            avg=avg+z;

            if( z > high ) {
                high=z;
            }

            if( z < low ) {
                low=z;
            }
        }

        if( debug ) {
            Sys.println( "z low           : " + low );
            Sys.println( "z high          : " + high );
        }

        return ((avg-high)-low)/(arr.size()-2);
    }

    //! The given info object contains all the current workout
    //! information. Calculate a value and return it in this method.
    function compute(info) {
        var averagePace=0.0;
        var trendPace=0.0;
        var trend;


        if( debug ) {
            Sys.println( "-----------------" );
            Sys.println( "Elapsed time    : " + info.elapsedTime );
        }

        if( info.elapsedTime == null || info.currentSpeed == null || info.elapsedTime == 0 ) {
            return "--";
        }

        if( debug ) {
            Sys.println( "Current speed   : " + info.currentSpeed );
            Sys.println( "Current pace    : " + speedToPace(info.currentSpeed) );
            Sys.println( "Distance        : " + info.elapsedDistance );
            Sys.println( "Average index   : " + averageIndex );
            Sys.println( "Average readings: " + averageReadings );
            Sys.println( "Trend index     : " + trendIndex );
            Sys.println( "Trend readings  : " + trendReadings );
        }

        averageArray[averageIndex]=info.currentSpeed;
        averageIndex++;

        trendArray[trendIndex]=info.currentSpeed;
        trendIndex++;

        if( averageIndex == averagePeriod ) {
            averageIndex=0;
        }

        if( trendIndex == trendPeriod ) {
            trendIndex=0;
        }

        if( trendReadings < trendPeriod ) {
            trendReadings++;
        }

        if( averageReadings < averagePeriod ) {
            averageReadings++;

            return "--";
        }


        // Get the average
        averagePace=getArrayAverage(averageArray);

        // Convert from speed to pace (from m/s to min/km)
        averagePace=speedToPace(averagePace);


        // Get the average
        trendPace=getArrayAverage(trendArray);

        // Convert from speed to pace (from m/s to min/km)
        trendPace=speedToPace(trendPace);


        if( trendPace > averagePace*1.1 ) {
            trend="/";
        } else if( trendPace > averagePace ) {
            trend="-";
        } else if( trendPace < averagePace*0.9 ) {
            trend="*";
        } else if( trendPace < averagePace ) {
            trend="+";
        } else {
            trend="=";
        }

        if( debug ) {
            Sys.println( "Trend pace      : " + trendPace.format("%.2f"));
            Sys.println( "Average pace    : " + averagePace.format("%.2f") + trend);
        }

        if( averagePace == 0 ) {
            return "-.--" + trend;
        } else {
            return averagePace.format("%.2f") + trend;
        }
    }

}