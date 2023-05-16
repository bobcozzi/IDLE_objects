# IDLE_objects
# Find old/unused objects on IBM i
# NOTE: If you specify *ALL/*ALL for the library and object name
# this will be a long running process depending on the system size.
# I recommend first using it over a single library or a generic library. 
# Then if that looks good, run it over *ALLUSR or similar.

     -- ----------------------------------------------------------------
     -- Description: List Objects with old last used date
     -- Alt Title:   List Idle (old/unused) Objects
     -- Author:      R.Cozzi,Jr.
     -- Copyright:   (c) 2023 - R.Cozzi,Jr. All rights reserved.
     -- Rights assignment:
     --              Reproduction in whole or part is granted provided
     --              this copyright and comment block is included and
     --              the original author is clearly credited.
     -- ----------------------------------------------------------------

This UDTF returns a list of object that have not been used
for at least the period (in months) specified on the PERIOD parameter.
These are referred to as "idle objects".
The function optionally includes objects that have never been used.
These are referred to as "unused objects".
This function is part of:
SQL Tools for IBM i
(c) 2021-2023 by R. Cozzi. Jr.
All rights reserved.
