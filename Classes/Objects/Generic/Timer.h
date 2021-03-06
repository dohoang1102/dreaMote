//
//  Timer.h
//  dreaMote
//
//  Created by Moritz Venn on 09.03.08.
//  Copyright 2008-2011 Moritz Venn. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <Objects/EventProtocol.h>
#import <Objects/TimerProtocol.h>
#import <Objects/ServiceProtocol.h>

/*!
 @brief Event Types in Neutrino.

 @note We ignore everything except zapto&standby currently but this is here
 in case we need it later.
 */
enum neutrinoEventType {
	neutrinoTimerTypeShutdown = 1, /*!< @brief Shut STB down. */
	neutrinoTimerTypeNextprogram = 2, /*!< @brief ??? */
	neutrinoTimerTypeZapto = 3, /*!< @brief Zap to a given Service. */
	neutrinoTimerTypeStandby = 4, /*!< @brief Enter Standby. */
	neutrinoTimerTypeRecord = 5, /*!< @brief Record a given Service. */
	neutrinoTimerTypeRemind = 6, /*!< @brief ??? */
	neutrinoTimerTypeSleep = 7, /*!< @brief ??? */
	neutrinoTimerTypePlugin = 8, /*!< @brief ??? */
};

/*!
 @brief Repeat Flags in Neutrino.
 */
enum neutrinoTimerRepeat {
	neutrinoTimerRepeatNever = 0, /*!< @brief Don't repeat.  */
	neutrinoTimerRepeatDaily = 1, /*!< @brief Repeat daily. */
	neutrinoTimerRepeatWeekly = 2, /*!< @brief Repeat every week. */
	neutrinoTimerRepeatBiweekly = 3, /*!< @brief Repeat every two weeks. */
	neutrinoTimerRepeatFourweekly = 4, /*!< @brief Repeat every four weeks. */
	neutrinoTimerRepeatMonthly = 5, /*!< @brief ??? Repeat on this day every month ??? */
	 /*!
	  @brief ???
	  @note Unimplemented in Neutrino?
	*/
	neutrinoTimerRepeatByDescription = 6,
	neutrinoTimerRepeatWeekdays = 0x100, /*!< @brief Repeat on given weekdays */
	neutrinoTimerRepeatMonday = 256, /*!< @brief Repeat on Monday. */
	neutrinoTimerRepeatTuesday = 512, /*!< @brief Repeat on Tuesday. */
	neutrinoTimerRepeatWednesday = 1024, /*!< @brief Repeat on Wednesday. */
	neutrinoTimerRepeatThursday = 2048, /*!< @brief Repeat on Thursday. */
	neutrinoTimerRepeatFriday = 4096, /*!< @brief Repeat on Friday. */
	neutrinoTimerRepeatSaturday = 8192, /*!< @brief Repeat on Saturday. */
	neutrinoTimerRepeatSunday = 16384, /*!< @brief Repeat on Sunday. */
};

/*!
 @brief Generic Timer.
 */
@interface GenericTimer : NSObject <TimerProtocol>
{
@private
	double _duration; /*!< @brief Event Duration. */
}

/*!
 @brief Initialize with existing Timer.
 
 @note Required to create a Copy.
 @param timer Existing Timer.
 @return Timer instance.
 */
- (id)initWithTimer:(NSObject<TimerProtocol> *)timer;

/*!
 @brief Create Timer with attributes from given Event.
 
 @param ourEvent Event.
 @return Timer instance.
 */
+ (NSObject<TimerProtocol> *)withEvent: (NSObject<EventProtocol> *)ourEvent;

/*!
 @brief Create Timer with attributes from given Event and Service.
 
 @param ourEvent Event.
 @param ourService Service.
 @return Timer instance.
 */
+ (NSObject<TimerProtocol> *)withEventAndService: (NSObject<EventProtocol> *)ourEvent: (NSObject<ServiceProtocol> *)ourService;

/*!
 @brief Create new Timer.

 @return Timer instance.
 */
+ (NSObject<TimerProtocol> *)timer;

@end
