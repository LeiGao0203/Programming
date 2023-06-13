proc import datafile = '/home/u59019227/titanic/train.csv'  
    out = train 
    dbms=csv 
    replace;
run;
proc import datafile = '/home/u59019227/titanic/test.csv'  
    out = test 
    dbms=csv 
    replace;
run;

data full;
set train 
	test;
by passengerid;
run;

* Explore and Clean data;
proc contents data=full;
run;

proc freq data = full;
table survived;
run;


proc freq data=full;
table embarked * sex ;
run;


* Create features;
data	full_cleaned;
set		full;
if Sex = "female"	then Sex_F = 1;
					else Sex_F = 0;
if embarked = "S"				then embarked_num = 1;
if embarked = "C"				then embarked_num = 2;
if embarked = "Q"				then embarked_num = 3;
run;

proc corr data = full_cleaned;
run; 

data train_cleaned test_cleaned;
set full_cleaned;
if survived =. then output test_cleaned;
else output train_cleaned;
run;
				

* Forward Selection (based on AIC);

* Round 1;
*					Intercept Only	Intercept and Covariates
	pclass			1188.655		1088
	age				966.516			964
	sibsp			1188.655		1189(out)
	parch			1188.655		1184(out)
	fare			1188.655		1121
	sex_F			1188.655		921
	embarked_num	1184.818		1176(out)
	;

proc  logistic data=train_cleaned;
model survived = sex_F;
run;

* result: add sex_F;


* Round 2;
*					Intercept Only	Intercept and Covariates
*	pclass			1188.655		833.196
	age				966.516			755.957
	fare			1188.655		890.310		
	;
proc  logistic data=train_cleaned;
model survived = sex_F fare;
run;
* result: add age;


* Round 3;
*					Intercept Only	Intercept and Covariates
*	pclass			966.516			655.291
	fare			966.516			724.071		
	;
proc  logistic data=train_cleaned;
model survived = sex_f age fare;
run;
* result: add fare;


* Round4 test adding pclass ;
*					Intercept Only	Intercept and Covariates
*	pclass			966.516			657.230
	;
proc  logistic data=train_cleaned;
model survived = sex_f age fare pclass;
run;
* result: not add pclass;

proc  logistic data=train_cleaned outmodel=final_model;
model survived = sex_f age fare;
run;

* assess model baed on holdout;
proc logistic inmodel=final_model;
score data=test_cleaned  out= prediction;
run;

proc import datafile = '/home/u59019227/MA603/PROJ_1/gender_submission.csv'  
    out = submission 
    dbms=csv 
    replace;
run;

data submit;
set prediction;
keep PassengerId I_survived;
run;

data submit;
set submit;
rename I_Survived = Survived;
run;

proc export data=submit
    outfile='/home/u59019227/titanic/output/submission.csv'
    dbms=csv
    replace;
 run;
