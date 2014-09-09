//
//  utils.cpp
//  edda
//
//  Created by Mauricio Giraldo on 8/9/14.
//  Copyright (c) 2014 Ping Pong Estudio. All rights reserved.
//

#include "utils.h"
#include "math.h"
#include "float.h"

#pragma mark - from oF
float ofMap(float value, float inputMin, float inputMax, float outputMin, float outputMax, bool clamp) {
	
	if (fabs(inputMin - inputMax) < FLT_EPSILON){
		return outputMin;
	} else {
		float outVal = ((value - inputMin) / (inputMax - inputMin) * (outputMax - outputMin) + outputMin);
		
		if( clamp ){
			if(outputMax < outputMin){
				if( outVal < outputMax )outVal = outputMax;
				else if( outVal > outputMin )outVal = outputMin;
			}else{
				if( outVal > outputMax )outVal = outputMax;
				else if( outVal < outputMin )outVal = outputMin;
			}
		}
		return outVal;
	}
	
}
