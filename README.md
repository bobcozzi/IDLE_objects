# IDLE_objects
Find old/unused objects on IBM i

     -- ----------------------------------------------------------------
     -- Description: List Old/Unsused ("Idle") Objects
     -- Alt Title:   List Old Objects
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
