proc import datafile = '/home/****/titanic/train.csv'  
    out = train 
    dbms=csv 
    replace;
run;
proc import datafile = '/home/****/titanic/test.csv'  
    out = test 
    dbms=csv 
    replace;
run;
proc import datafile = '/home/****/titanic/gender_submission.csv'  
    out = submission 
    dbms=csv 
    replace;
run;

%macro clean_data(table = );
	data	&table._titanic;
	set		&table;
	if Sex = "female"	then Sex_F = 1;
						else Sex_F = 0;
	if embarked = "Q"				then embarked_q = 1;
									else embarked_q = 0;
	if embarked = "C"				then embarked_c = 1;
									else embarked_c = 0;
	if embarked = "S"				then embarked_s = 1;
									else embarked_s = 0;
	run;
%mend;

%clean_data(table = train);
%clean_data(table = test);

* Forward Selection (based on AIC);

* Round 1;
*	pclass			1088
	age				964
	sibsp			1189
	parch			1184
	fare			1121
	sex_F			921
	embarked_c		1166
	embarked_q		1190
	embarked_s		1169
	;

proc  logistic data=train_titanic;
model survived = embarked_s;
run;

* result: add sex_F;

* Round 2;
*	pclass			833
	age				755
	Parch			920			
	fare			890
	;

proc  logistic data=train_titanic;
model survived = sex_f parch;
run;

* result: add age;

* Round 3;
*	pclass			655
	Parch			755			
	fare			724
	;
proc  logistic data=train_titanic;
model survived = sex_f age pclass;
run;

*result: add pclass;

proc  logistic data=train_titanic;
model survived = sex_f age pclass ;
run;


/* output the model */
proc  logistic data=train_titanic outmodel=titanic_model;
model survived = sex_f age pclass ;
run;


data test_titanic;
merge submission test_titanic;
by passengerid;
run;

/* need to use another dataset as test dataset, merge submission and test */
proc logistic inmodel=titanic_model;
score data=test_titanic fitstat;
run;
/* AUC 0.9819  */
/* Brier Score 0.07935 */
