libname data "/home/u59019227/MA603/PROJ_1";

* Explore and Clean data;
proc contents data=data.Titanic;
run;
proc freq data = data.Titanic;
run;


* Create features;
data	Titanic_data;
set		data.Titanic;
if pclass = 1 		then pclass_1 = 1;
					else pclass_1 = 0;
if pclass = 2		then pclass_2 = 1;
					else pclass_2 = 0;
if pclass = 3		then pclass_3 = 1;
					else pclass_3 = 0;
if Sex = "female"	then Sex_F = 1;
					else Sex_F = 0;
if Age < 20						then Teen = 1;
								else Teen = 0;
if Age >= 20 and Age < 30		then YoungAdult = 1;
								else YoungAdult = 0;
if Age >= 30 and Age < 40		then GenX  = 1;
								else GenX  = 0;
if Age >= 40 and Age < 60		then MiddleAge = 1;
								else MiddleAge = 0;
if Age >= 60					then Senior = 1;
								else Senior = 0;
if embarked = "Q"				then embarked_q = 1;
								else embarked_q = 0;
if embarked = "C"				then embarked_c = 1;
								else embarked_c = 0;
if embarked = "S"				then embarked_s = 1;
								else embarked_s = 0;

run;

* Divide modeling data;
* streaminit sets the seed for the random number generator,
	allowing results to be reproduced ;
data	_NULL_;
call streaminit(60);
run;

data	Titanic_Train Titanic_Test Titanic_Holdout;
set		Titanic_data (drop=sex cabin home_dest boat body ticket embarked);
r = rand("Uniform");
if r < .7	then output Titanic_Train	; else
if r < .85	then output Titanic_Test	; else
				 output Titanic_Holdout;
run;
proc print data = Titanic_Train;run;

* Forward Selection (based on AIC);

* Round 1;
*	pclass_1		1189
	pclass_2		1252
	pclass_3		1175
	age				1022
	sibsp			OUT
	parch			1247
	fare			1191
	sex_F			951
	teen			OUT
	YoungAdult		OUT
	GenX			OUT
	MiddleAge		OUT
	Senior			OUT
	embarked_c		1223
	embarked_q		OUT
	embarked_s		1234
	r				OUT;

proc  logistic data=Titanic_Train;
model survived = 	pclass_1;
run;
* result: add sex_F;

* Round 2;
*	pclass_1		901
	pclass_2		OUT
	pclass_3		895
	age				OUT
	Parch			OUT			
	fare			922
	embarked_c		925
	embarked_s		943;

proc  logistic data=Titanic_Train;
model survived = sex_f pclass_3;
run;
* result: add pclass_3;

* Round 3;
*	pclass_1		887
	fare			891
	embarked_c		879
	embarked_s		887;

proc  logistic data=Titanic_Train;
model survived = sex_f pclass_3 pclass_1;
run;
* result: add age embarked_c;

* Round 4;
*	pclass_1		877
	fare			OUT
	embarked_s		OUT;
proc  logistic data=Titanic_Train;
model survived = sex_f pclass_3 embarked_c pclass_1;
run;


* fit model on Testing data ;
proc  logistic data=Titanic_Test;
model survived =  sex_f pclass_3  pclass_1 embarked_c;
run;
* Eliminate embarked_c pclass_3;

* re-fit model on train + test data ;
data	Titanic_Train_Test (drop=r);
set		Titanic_Train Titanic_Test;
run;
proc  logistic data=Titanic_Train_Test;
model survived = sex_f pclass_1 ;
run;



proc  logistic data=Titanic_Train_Test outmodel=auto_model;
model survived = sex_f pclass_1   ;
run;

* assess model baed on holdout;
proc logistic inmodel=auto_model;
score data=Titanic_Train_Test fitstat;
run;
proc logistic inmodel=auto_model;
score data=Titanic_Holdout fitstat;
run;
