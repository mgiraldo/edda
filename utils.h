//
//  utils.h
//  edda
//
//  Created by Mauricio Giraldo on 8/9/14.
//  Copyright (c) 2014 Ping Pong Estudio. All rights reserved.
//

#ifndef edda_utils_h
#define edda_utils_h

#if defined(__cplusplus)
extern "C" {
#endif
	
	float ofMap(float value, float inputMin, float inputMax, float outputMin, float outputMax, bool clamp);

#if defined(__cplusplus)
}
#endif

#endif
