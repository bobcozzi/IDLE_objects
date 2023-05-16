

     -- List unused/idle objects (IDLE_OBJECTS) UDTF
     -- Returns a list of objects whose Last-Used date
     -- is at least as old as the "PERIOD" parameter.
     -- It may also include unused objects; those objects whose
     -- Last-Used date is null (i.e., they have never been used).

     -- Objects that match the OBJECT_NAME, LIBRARY_NAME, and OBJTYPE
     -- parameters are included (they default to *USRLIBL/*ALL *ALL).

     -- The "OPTION" parameter may be used to also include objects
     -- that have never been used (i.e., last-used date is NULL).

     -- This Function is created to be backward compatible with
     -- IBM i v7r2 and later.

     -- ----------------------------------------------------------------
     -- Description: List Idle and Unused Objects
     -- Alt Title:   List Old Objects
     -- Author:      R.Cozzi,Jr.
     -- Copyright:   (c) 2023 - R.Cozzi,Jr. All rights reserved.
     -- Rights assignment:
     --              Reproduction in whole or part is granted provided
     --              this copyright and comment block is included and
     --              the original author is clearly credited.
     -- ----------------------------------------------------------------

 CREATE or REPLACE FUNCTION sqltools.IDLE_OBJECTS(
                            LIBRARY_NAME varchar(10)  default '*USRLIBL',
                            OBJECT_NAME  varchar(10)  default '*ALL',
                            OBJTYPE      varchar(812) default NULL,
                            PERIOD       int          default 24,
                            OPTION       varchar(10)  default NULL
                                                )
           RETURNS TABLE (
                 OBJLIB  VARCHAR(10),    -- Object Library
                 OBJNAME VARCHAR(10),    -- Object Name
                 OBJTYPE VARCHAR(10),    -- Object Type
                 OBJATTR VARCHAR(10),    -- Extended object attribute
                 OBJSIZE BIGINT,         -- Object size (in bytes)
                 OBJOWNER VARCHAR(10),   -- Object Owner User profile
                 OBJCREATOR VARCHAR(10), -- Object created by User profile
                 CRTDATE    DATE,        -- Object creation date
                 LASTUSEDDATE DATE,      -- Object last-used date
                 IDLE_MONTHS VARCHAR(10),  -- Idle period (in months)
       -- If you are on V7R3 or later, you may want to
       -- include these two additional columns that are
       -- NOT available on V7R2:
       --          CRTSYSNAME VARCHAR(8) ,   -- Created-on system name
       --          CRTIBMi_VRM VARCHAR(9),   -- Created-on IBM i Version
                 OBJTEXT   VARCHAR(50)   -- Object text (description)
              )

     LANGUAGE SQL
     READS SQL DATA
     ALLOW PARALLEL
     NO EXTERNAL ACTION
     NOT FENCED
     NOT DETERMINISTIC
     SPECIFIC Z_LISTIDLE

    -- Date Format ISO is required for dates prior to 1940.
     set option datfmt = *ISO, commit=*NONE

R: BEGIN

     DECLARE  COPYRIGHT varchar(64) not null default
           'Copyright (c) 2023 by R. Cozzi, Jr. All rights reserved.';

     DECLARE  MONTHSOLD smallint not null default 24;
     DECLARE  UNUSED    int      not null default 0;
     DECLARE  OBJ_TYPE  VARCHAR(812) default '*ALL';
     DECLARE  OBJ_NAME  VARCHAR(10);
     DECLARE  LIB_NAME  VARCHAR(10)  default '*ALLSIMPLE';
     DECLARE  LIB_LIB   VARCHAR(10)  default '*ALLSIMPLE';
     DECLARE  LIB_GEN   int      not null default 0;

       -- The idle PERIOD parameter default to 24 (months)
       -- It controls how old the last used date must be
       -- before it is included. It must be at least PERIOD months old.

     IF (PERIOD is not NULL and PERIOD > 0) THEN
       set R.MONTHSOLD = PERIOD;
     end if;

       -- The Library name may be on of the supported special values
       -- such as *ALLUSR and *ALL, or it may be a full library name,
       -- or a generic library name such as 'POS*'.

     IF (LIBRARY_NAME is not NULL and LIBRARY_NAME <> '') THEN
       if (POSITION('"', LIBRARY_NAME) = 0) THEN
         set LIBRARY_NAME = UPPER(LIBRARY_NAME);
       end if;
       set R.LIB_NAME = strip(LIBRARY_NAME,L, ' ');  -- %TRIML()
     end if;

     if (LEFT(R.LIB_NAME,1) = '*') THEN
        set R.LIB_LIB = R.LIB_NAME;
     elseif (POSITION('*', R.LIB_NAME) > 1) THEN
        set R.LIB_NAME = Replace(R.LIB_NAME,'*','%');
        set R.LIB_LIB = '*ALLSIMPLE';
        set R.LIB_GEN = 1;
     else   -- For a full library name, we don't use OBJSTATS so
       set R.LIB_LIB = R.LIB_NAME;   -- force empty library list
     end if;

       -- The OPTION parameter indicates what to include
       -- OPTION=>'*ALL' both used and unused objects
       -- OPTION=>'*UNUSED' (same as *ALL)
       -- OPTION->'*IDLE' only idle objects are included (default)
       -- To INclude Unused Objects specify *UNUSED or *ALL
       -- To EXclude Unused Objects, omit this parameter or
       -- specify its default value of *IDLE, or blanks or NULL.

     IF ("OPTION" is not NULL and "OPTION" <> '') THEN
        set "OPTION" = strip("OPTION",L,' ');  -- Trim left-side blanks
        set "OPTION" = strip("OPTION",L,'*');  -- Remote leading * if any
        set "OPTION" = upper("OPTION");        -- Convert to uppercase
        -- I only check for *UNUSED, *ALL or *YES
        -- If it is one of these, then unused objects are included
        if (LEFT("OPTION",2) in ('UN','YE','AL')) THEN
          set R.UNUSED = 1;
        end if;
     end if;

       -- The OBJECT_NAME parameter may be *ALL, a generic name
       -- or a full name. It is unusual to use a full-name, however.

     set R.OBJ_NAME = NULL;
     IF (OBJECT_NAME is not NULL and OBJECT_NAME <> '') THEN
        -- We check if the parameter contains a (double) quoted name.
        -- If it does, we avoid converting it to upper case.
        -- Otherwise we convert it since 99.9999999% of all object
        -- names are not S/36-style "oBj@Name" names.
        -- So why force IBM i users type it in all caps?
       if (POSITION('"', OBJECT_NAME) = 0) THEN
         set OBJECT_NAME = UPPER(OBJECT_NAME);
       end if;

       -- The strip function works well on V7R2 and later
       -- The rTrim and lTrim functions are supported on V7R2,
       -- however they _sometimes_ fails at runtime on V7R2.
       -- Therefore I have resorted to using strip() exclusively
       -- since it always works.

       set R.OBJ_NAME = strip(OBJECT_NAME,B, ' ');  -- %TRIM()

       -- If the object name is generic (vs *ALL)
       -- we translate the * (asterisk) to the SQL LIKE-friendly percent.
       -- We do this because OBJECT_STATISTICS does not accept
       -- generic object names until late in V7R3. So we resort
       -- to using the WHERE OBJNAME LIKE R.OBJ_NAME in our code.

       if (POSITION('*', R.OBJ_NAME) > 1) THEN
         set R.OBJ_NAME = Replace(R.OBJ_NAME,'*','%');
       end if;
     end if;
     if (R.OBJ_NAME = '*ALL') THEN
       set R.OBJ_NAME = NULL;
     end if;

       -- The OBJTYPE parameter is one or more IBM i system object types.
       -- We used the built-in capability of the OBJECT_STATISTICS
       -- function of a list of one or more object types, with or
       -- without the leading asteris. However we do help it out
       -- and convert the list of object types to all upper case,
       -- since again, we are not animals! :)

     IF (OBJTYPE is not NULL and OBJTYPE <> '') THEN
        set R.OBJ_TYPE = upper(OBJTYPE);
     end if;

     -- The following is for debug purposes only.
     -- call sqlTools.sndmsg('Lib: ' concat rTrim(R.LIB_LIB) concat
     --        ' LibName: ' concat coalesce(rTrim(R.LIB_NAME),'*NULL') concat
     --        ' GenLib: '  concat R.LIB_GEN concat
     --        ' objtype: ' concat coalesce(rTrim(R.OBJ_TYPE),'*ALL') concat
     --        ' objName: ' concat coalesce(rTrim(R.OBJ_NAME),'*ALL') concat
     --        ' unused: '  concat R.UNUSED  concat
     --        ' age: '     concat R.MONTHSOLD);

     -- The Returned Table uses the an SQL CTE and SELECT stmt
     -- to produces the result via a LATERAL join OBJECT_STATISTICS
     return
       WITH LIBS(LIBNAME) as
       (      -- Build the list of libraries based on the LIBRARY_NAME parm.
         select R.LIB_NAME
           FROM sysibm.sysdummy1
           WHERE POSITION('*',R.LIB_NAME) <= 1 and
                 POSITION('%',R.LIB_NAME) = 0
        union
        select LL.OBJNAME
          FROM TABLE ( object_statistics(R.LIB_LIB, '*LIB','*ALLSIMPLE')) LL
          WHERE POSITION('%',R.LIB_NAME) > 0 AND
                LEFT(LL.OBJNAME, 1) NOT IN ('Q','#','$') AND
               (
               ((R.LIB_GEN=1 and LL.OBJNAME LIKE R.LIB_NAME) or R.LIB_GEN=0)
               )
       )
       select   -- Select "old" objects from the libraries
         left(od.OBJLONGSCHEMA,10) as OBJLIB,
         od.objname,
         od.objtype,
         od.objAttribute as objAttr,
         od.objsize,
         od.objowner,
         od.objdefiner AS OBJCREATOR,
         CAST(od.objcreated AS DATE) crtdate,
           -- last-used-timestamp's time component is garbage,
           -- so we throw it away with this CAST as DATE
         CAST(od.last_used_timestamp AS DATE) AS LASTUSEDDATE,
         CASE
           WHEN od.LAST_USED_TIMESTAMP IS NULL THEN '*UNKNOWN'
           ELSE
             LPAD(
               CAST(
               -- Check if the object is "old" using the
               -- MONTHS_BETWEEN function (introduced in V7R2)
                 CAST(
            MONTHS_BETWEEN(current_timestamp, od.last_used_timestamp) AS
                   DEC(7, 1)) AS VARCHAR(10)), 10)
         END IDLE_MONTHS,  -- The result is the idle period
          -- If you are on V7R3 or later you may also include
          -- these two columns if desired.
       --   OD.CREATED_SYSTEM ,
       --   OD.CREATED_SYSTEM_VERSION,

         od.objtext

            -- Using the LIBS intermediate result, we use a LATERAL JOIN
            -- to generate a list of objects in each library that matches
            -- the selection criteria (note the nested SELECT).
       FROM LIBS LL,
         LATERAL (SELECT D.*
           FROM TABLE (object_Statistics(LL.LIBNAME,
                                         R.OBJ_TYPE,'*ALLSIMPLE')) OL,
            LATERAL( select D1.* from TABLE(OBJECT_STATISTICS(
                               OL.OBJLONGSCHEMA,
                               OL.OBJTYPE,
                               OL.OBJNAME)) D1
                WHERE ((D1.last_used_timestamp is NULL and R.UNUSED = 1) or
                        D1.Last_used_timestamp <
                              current_date - R.MONTHSOLD months) AND
                       (OL.OBJNAME LIKE coalesce(R.OBJ_NAME,OL.OBJNAME))
                ) D
           WHERE  OL.OBJNAME LIKE coalesce(R.OBJ_NAME,OL.OBJNAME) AND
                  LEFT(OL.OBJLONGSCHEMA,1) NOT IN ('#','$','Q')
       ) OD;

end;

LABEL on specific routine sqltools.Z_LISTIDLE IS
'Create list of idle/unused objects';

comment on specific function sqltools.Z_LISTIDLE IS
'This UDTF returns a list of object that have not been used
for at least the period specified (in months) on the PERIOD parameter.
These are referred to as <i>idle objects</i>.
It optionally also returns objects that have never been used.
These are referred to as <i>unused objects</i>.';

comment on parameter specific function sqltools.Z_LISTIDLE
(
LIBRARY_NAME is 'The library whose objects are to be checked for
the not used period of months specified on the PERIOD parameter,
A generic name, full name or one of the following special values
may be used:<ul>
<li>*ALL - All libraries</li>
<li>*ALLAVL - All libraries in all available ASPs</li>
<li>*ALLUSR - All user libraries in ASP(*SYSBAS)</li>
<li>*ALLUSRAVAL - All user libraries in all ASPs</li>
<li>*LIBL - The libraries on the job''s library list</li>
<li>*CURLIB - The job''s current library</li>
<li><u>*USRLIBL</u> - The libraries on the user-portion of the
 the job''s library list. This is the default.</li>
</ul>Significant performance improvement can be observed when using
*LIBL, *CURLIB, *USRLIBL or a specific library name.',

OBJECT_NAME is 'An object name, generic, full, or *ALL to be returned.
Only objects whose name matches this parameter are returned. The default
is *ALL. For example OBJECT_NAME=>''ORD*'' includes all objects whose names
begin with ''ORD'' that have not been used for at least PERIOD months.',

OBJTYPE is 'A list of one or more IBM i object types, separated by at least
one blank. The default is *ALL object types. Only objects of the type(s)
specified on this parameter are included in the resultSet.',

 PERIOD IS 'The idle period in months (number of months old) an
 object''s Last-Used date must be to be included in the the resultSet.
 The default is 24 months.',

 "OPTION" IS 'The unused objects option. By default objects that have been
 idle for PERIOD months or longer are included. Objects that have NEVER
 been used are, by default, omitted. To also include those never-used
 objects, specify one of the following options:<ul><li>
 <u>*IDLE</u> - Only idle objects are returned. This is the default.</li>
 <li>*ALL - Idle and never-used objects are included in the resultSet.</li>
 <li>*UNUSED - Idle and never-used objects are included in the resultSet.</li>
 </ul>Note that *ALL and *UNUSED are synonyms. If this parameter is
 not specified, is null or blanks, then the default *IDLE is used.'

);

GRANT EXECUTE
ON SPECIFIC FUNCTION SQLTOOLS.Z_LISTIDLE TO PUBLIC;

GRANT ALTER , EXECUTE
ON SPECIFIC FUNCTION SQLTOOLS.Z_LISTIDLE TO QSYS WITH GRANT OPTION ;
 
