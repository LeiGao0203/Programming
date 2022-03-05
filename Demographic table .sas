libname proj1 '/home/u59019227/proj1';

/* step1 */
/* import file as a dataset */
proc import datafile='/home/u59019227/proj1/task1/ADSL.xlsx' OUT=ADSL	
dbms= xlsx;
run;


data ADSL_1 (drop = ITTFL NEREASN BORRESP Trt01a Trt01p USUBJID trt01an trt01pn);
set ADSL;
RENAME 	AGegr1 = AGE_CATE
		race = VARRACE
		sex = VARSEX 
		ethnic = VARETHNIC 
		country = VARCOUNTRY
		trt01p = VARTRT;
run;

/* step2 */
proc sort data=ADSL_1;
by VARTRT;
run;

%MACRO FREQ (tables=);
	proc freq data=ADSL_1;
	tables &tables /out = &tables;
	by  vartrt ;
	run;
%mend;


%macro sort  (tables=);
	proc sort data = &tables;
	by &tables;
	run;
%mend;


/* transpose dataset */
%macro trans ( tables=);
	proc transpose data = &tables out = &tables._t;
		id vartrt;
		by &tables;
	run;
	
	data &tables._t;
		format &tables $35.;
		set &tables._t;
	run;
%mend;


%macro data_clean (tables =);
	data &tables._clean (rename=('Drug a'n =DrugA &tables = catego));
	set &tables._t;
	drop _NAME_ _LABEL_;
	if _NAME_ = 'COUNT';
	Var = "&tables";
	if druga = . then druga = 0;
	if placebo =. then placebo = 0;
	run;
%mend;


%macro format (tables = );
proc sql;
select sum(druga) into: total_a
from &tables._clean;
quit;


proc sql;
select sum(placebo) into: total_p
from &tables._clean;
quit;
proc sql;
select sum(placebo + druga) into: total
from &tables._clean;
quit;

data &tables._format (keep = catego var a_chr p_chr total_chr);
set &tables._clean;
a_per = put((druga / &total),percent7.1);
p_per = put((placebo/ &total),percent7.1);
total_per = put(((druga+placebo)/&total),percent7.1);

A_chr = druga||"("||a_per||")";
P_chr = placebo||"("||p_per||")";
total_chr = (druga+placebo)||"("||total_per||")";

/* rename p_final = "Placebo N=&total_p"n; */
/* rename a_final = "Drug A N=&total_a"n; */
/* rename total_final = "total N=&total"n; */
run

%mend;
%format (tables = varethnic);


%macro get_pre(tables=);
%freq(tables = &tables);
%sort(tables = &tables);
%trans(tables = &tables);
%data_clean( tables = &tables);
%format(tables = &tables);
%mend;


/* tables = varrace, varsex, varethnic, age_cate, varcountry */
/* get dataset varrace_pre, varsex_pre, carethnic_pre, agecate_pre, varcountry_pre */
%get_pre(tables = varrace);
%get_pre(tables = varsex);
%get_pre(tables = varethnic);
%get_pre(tables = age_cate);
%get_pre(tables = varcountry);


DATA num;
set age_cate_format
	varsex_format
	varrace_format
	varethnic_format;
run;
	
/* age pltcnt */
%macro means (variable =);
	proc means data = ADSL_1 ;
		var pltcnt;
		class vartrt;
		output out = &variable._mean n = N mean = MEAN median = MEDIAN min = MIN max = MAX stddev = STANDARD_DEVIATION;
	run;
%mend;

%means (variable = age);
%means (variable = pltcnt);


data age_mean2 (drop = _type_ _freq_);
set age_mean;
if vartrt = "" then vartrt = "total";
run;

data pltcnt_mean2 (drop = _type_ _freq_);
set pltcnt_mean;
if vartrt = "" then vartrt = "total";
run;

proc sort data=age_mean2;by vartrt;run;
proc sort data=pltcnt_mean2;by vartrt;run;

proc transpose data = age_mean2 out=age_mean3;
id vartrt;
run;
proc transpose data = pltcnt_mean2 out=pltcnt_mean3;
id vartrt;
run;



/* age pltcnt */
%macro a_p_format (variable=);

data &variable._mean4;
set &variable._mean3;
rename 
	_name_ = catego 
	_label_ = var;
	
_label_ = "&variable";
a_chr = put('drug a'n,21.1);
p_chr = put(placebo,21.1);
total_chr = put(total,21.1);
run;

data &variable._mean5 (drop = total 'drug a'n placebo);
set &variable._mean4;
run;

%mend;

%a_p_format (variable = age);
%a_p_format (variable = pltcnt);

data finalset_task1 ;
set age_mean5 num pltcnt_mean5;
run; 

/* create report */
ods pdf file = '/home/u59019227/proj1/task1/task1.pdf';
proc report data=finalset_task1 nofs headline headskip;

title1 "Demographic and Baseline Characteristics Summary";
title2 "All tanckmized Subjects";

column var catego a_chr p_chr total_chr;


define var / group ' ' noprint ;
define catego / display STYLE(COLUMN)={leftmargin=.3in};
define a_chr / display 'TRT A/N = 50';
define p_chr / display 'TRT P/N = 50';
define total_chr / display 'Total/N = 100';

compute after var;
line ' ';
endcomp;

compute before var;
line var $10.;
endcomp;
run;

ods pdf close;
