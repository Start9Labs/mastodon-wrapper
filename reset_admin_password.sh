#!/bin/bash

exec tootctl accounts modify --reset-password `tootctl accounts get-admin-username`