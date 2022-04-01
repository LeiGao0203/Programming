/* import data */
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
proc import datafile = '/home/u59019227/titanic/gender_submission.csv'  
    out = submission 
    dbms=csv 
    replace;
run;

/* speficy plot size */
ods graphics / width=640px height=640px; 
 
proc print data = train;  
title 'Sample output of the Data'; 
run;

proc contents data=train; *For meta data; 
title 'Summary of training data'; 
run;

%macro Reg_searchReplace(df= , col=, newcol= , regex=);
 data &df;
  set &df;
   &newcol = &col;
   array Chars[*] &newcol; 
   do i = 1 to dim(Chars); 
    retain re;
    re = prxparse(&regex); 
    Chars[i] =  prxchange(re, -1,Chars[i]); 
    ;  
   end;
   drop re i;*drop newly creatd temp columns;
 run;
%mend Reg_searchReplace;

%Reg_searchReplace(df = full, col = Name, 
newcol = Title_col, regex = 's/(.*, )|( .*)//');

proc freq data = full;
title 'Contingency Table of Male and Female and their Titles';
tables Sex*Title_col / nopercent nocol norow;
run;

*replace unfrequent titles with rare;
 data full;
  set full;
   Title_col = translate(Title_col,'','.');
   Title_col = translate(Title_col,'',' '); 
   re = prxparse('s/Mlle/Miss/');
   Title_col = prxchange(re, -1,Title_col);
   re = prxparse('s/Ms/Miss/');
   Title_col = prxchange(re, -1,Title_col);
   re = prxparse('s/Mme/Mrs/');
   Title_col = prxchange(re, -1,Title_col);
   array Chars{11} $ ('Dona', 'Lady', 'the Countess','Capt', 'Col', 'Don', 'Dr', 'Major', 'Rev', 'Sir', 'Jonkheer'); 
   do i = 1 to dim(Chars);
    regex_1 = catx('','s/',Chars[i]);
    regex_1 = compress(catx('',regex_1, '/Rare/'));
    re = prxparse(regex_1); 
    Title_col =  prxchange(re, -1,Title_col); 
/*     regex; */
    ;  
   end;
   drop Chars1 Chars2 Chars3 Chars4 Chars5 Chars6 Chars7 Chars8 Chars9 Chars10 Chars11 regex_1 i re;
 run;
 
proc freq data = full;
title 'Contingency Table of Male and Female and their Titles';
tables Sex*Title_col / nopercent nocol norow ;
run;

 data full;
  set full;
   Fsize = SibSp + Parch + 1;
   FsizeD = 'Singleton';
   if Fsize > 1 and Fsize < 5 then FsizeD = 'small';
   if Fsize > 4 then FsizeD = 'large';
  run;
  
proc sgplot data = full;
  vbar Fsize / group= Survived groupdisplay = cluster;
 title 'Survival vs Family Size';
 run;
 
ods graphics on;
 proc freq data=full;
 tables Survived*FsizeD / norow nofreq plots=MOSAIC; 
 title 'Mosaic Plot Fsize Desc. vs Survived';
 run;
ods graphics off;

 data full;
  set full;
   Deck = substr(Cabin,1,1);
 run;
 
proc sgplot data = full;
  vbox Fare / category=Embarked group=Pclass;  
  refline 80;
 title 'Fare vs Embarkment';
 run;
 
data full; 
  set full;
   if PassengerId = 62 then Embarked = 'C';
   if PassengerId = 830 then Embarked = 'C';
 run;

proc format;
   value $missfmt ' '='Missing' other='Not Missing';
   value  missfmt  . ='Missing' other='Not Missing';
 run;

 proc freq data=full; 
  format _CHAR_ $missfmt.; 
  tables _CHAR_ / missing missprint nocum nopercent;
  format _NUMERIC_ missfmt.;
  tables _NUMERIC_ / missing missprint nocum nopercent;
 run;
 
%macro getMissing(df=);
data missing;
  set &df;
   numMissing = 0;
   array cols1 _numeric_;
   do over cols1;
    numMissing = numMissing + cmiss(cols1);;
   end;
  
   array cols2 _character_;
   do over cols2;
    numMissing = numMissing + cmiss(cols2);;
   end;
 run;
 
 proc sql;
 title 'Rows with missing values'; 
 select * from missing where numMissing > 0;
 quit;
%mend getMissing;

*Subset dataframe with columns that don't have too many missing values;
 data sub_full;
  set full;
   drop Cabin Deck Age Survived;
  run;

%getMissing(df = sub_full);
/* find out passenger 1044 miss fare */

/* visualized the distribution */
proc sql;
 create table sub_full as
 select * from full
 where Pclass = 3 and Embarked = 'S';
 quit;
proc sgplot data = sub_full;
 title 'Density of Fare'; 
 histogram Fare;
 run;
 
*impute values with median value;
 proc sql;
     update full
     set Fare = (select median(Fare) from sub_full) 
     where PassengerId = 1044;
 quit;
 run;
 
proc sql;
  select * from full
  where PassengerId = 1044;
 quit;


/* 3.2 Predictive imputation */
proc mi data= full nimpute=1 out=full seed=54321;
 class Embarked FsizeD Title_col Sex;
 monotone regression ;
 var Pclass Fsize Parch Embarked FsizeD Title_col Sex Age;
 run;
 
 data full;
  set full;
   Age = abs(age);
 run;
 
data sub_full;
  set full;
  if cmiss(of Survived) =0;
 run;
 proc sgpanel data = sub_full;
 title 'Age faceted by Survival & Sex';
 panelby Sex;
 histogram Age / group=Survived nbins= 30;
 run;

data full;
  set full;
   Child = 'Child';
   if Age >= 18 then Child = 'Adult';
   Mother = 'Not Mother';
   *https://www.educba.com/sas-operators/;
   if Sex = 'female' and Parch > 0 and Age > 18 and Title_col ~= 'Miss' then Mother = 'Mother';
 run;
 
 data sub_full;
  set full;
  if cmiss(of Survived) =0;
  
/*  check if child has better chance */
 proc freq data = sub_full;
 title 'Contingency Table Child Var';
 tables Child*Survived / nopercent nocol norow;
 run;
 
/*  check if mother has batter chance */
 proc freq data = sub_full;
 title 'Contingency Table Mother Var';
 tables Mother*Survived / nopercent nocol norow;
 run;
 
/***********************************************************************/
Data Train;
  set full;
   if PassengerId <= 891;
   keep Survived Pclass Sex Age SibSp Parch Fare Embarked Title_col FsizeD Child Mother;
  run;
 Data Test;
  set full;
   if PassengerId > 891;
   keep Pclass Sex Age SibSp Parch Fare Embarked Title_col FsizeD Child Mother;
  run;

proc hpforest data = Train maxtrees = 50 seed = 14561 trainfraction=0.85;
 input Pclass Sex Age SibSp Parch Fare Embarked Title_col FsizeD Child Mother;
 target Survived / level = BINARY;
 ods output FitStatistics = fit_at_runtime;
 ods output VariableImportance = Variable_Importance;
 ods output Baseline = Baseline;
run;

title "The Average Square Error";
 proc sgplot data = fit_at_runtime;
  series x=NTrees y=PredAll/legendlabel='Train Error';
  series x=NTrees y=PredOOB/legendlabel='OOB Error';
  xaxis values=(0 to 50 by 1);
  yaxis values=(0 to 0.3 by 0.05) label='Average Square Error';
 run;

title "Feature Importance Gini";
 proc sgplot data = Variable_Importance;
 vbar Variable /response=Gini  groupdisplay = cluster categoryorder=respdesc;
 run;
 
proc hpforest data = Train maxtrees= 500 trainfraction=0.85
     leafsize=1 alpha= 0.1 seed = 14561;
 input Pclass Sex Age SibSp Parch Fare Embarked Title_col FsizeD Child Mother;
 target Survived / level = BINARY;
 ods output FitStatistics = fit_at_runtime;
 save file = "/home/u59019227/titanic/output/model_fit.bin"; 
 run;
 
 proc hp4score data=Test; 
 score file= "/home/u59019227/titanic/output/model_fit.bin"
 out=Predictions;
 run;
 
 data submission;
  merge submission Predictions;
 run;

data submission;
set submission;
keep PassengerId I_Survived;
run;

data submission;
set submission;
rename I_Survived = Survived;
run;


proc export data=submission
    outfile='/home/u59019227/titanic/output/submission.csv'
    dbms=csv
    replace;
 run;