# U19-GUI
This repository contains the source code of MATLAB GUI of the animal and behavioral information. This is a brief documentation of
* Startup
* Code use
* Code structure
* Work to do
* Known issues
* Health checks done (can be removed once we are happy).

# Startup
Start matlab, add U19-pipeline-matlab to the search path and add U19-GUI to the search patch

# Code documentation
## General use
This interface allows for programmatic access and update of the contained data. In your program you should first create an instance of the database to interact with:

      dbase     = AnimalDatabase();                       % keep this object around for communications
      dbase.gui();                                        % user interface from which one can add/view animals

There are a series of "pull*" functions to retrive info at various levels:

      [people, templates] = dbase.pullOverview();
      animals   = dbase.pullAnimalList();                 % all researchers
      animals   = dbase.pullAnimalList('sakoay');         % a single researcher with ID = sakoay
      logs      = dbase.pullDailyLogs('sakoay');          % all animals for sakoay
      logs      = dbase.pullDailyLogs('sakoay','K62');    % a particular animal ID for sakoay

To write data to the database, use the following "push*" functions:

      db.pushAnimalInfo('testuser', 'testuser_T01', 'initWeight', 23.5)
      db.pushDailyInfo( 'testuser', 'testuser_T01', 'received', 1.3, 'weight', 22.5);

And of course, you can also use all low-level datajoint functions.

## Code structure
Some general comments about architecture of the GUI

All reading from the database is done via the functions
* *pullAnimalList*
* *pullOverview*
* *pullDailyLogs*
* And of course all dj-queries (e.g. for templates)

All writing into the spreadsheets happens in the functions
* *pushDailyInfo*
* *pushAnimaInfo*
* *writeTrainingDataToDatabase.m* (uses *pullAnimalList* and *pushDailyInfo* of the animalDatabase)

The notification system is called periodically and the GUI sends out eMails and messages. This happens via the files
* *checkActionItems.m *
* *checkCageReturn.m*
* *checkMouseWeighing.m *

## Work to do
* Remove the delete mouse button (or update: only works if you have the required user rights).
* Remove the check in/out button.
* Write either a new GUI to add a new user, or alternatively add “new user” field to existing GUI, so that new users don’t have to be entered with SequelPro.
* Clean up code. This repo started as a branch of tankmousevr. I think the only relevant stuff for the GUI is in /database/. AnimalDatabase.m should be ok, but need to go through other code.
* Add additional feature: If animal reaches endpoint via 1910 protocol. Automatically and immediately send emails to people specified in a list (new dj table).

## Known issues/features
* Adding a new line will throw an error. This is on purpose to avoid typoes and enforce standards in gene/line identity. Should we add dialog to add new line?

## Health Check
* I checked add mouse, dead mouse, add action items, body weight, lines… Can you break it?
* To play with, fiddle with ‘testuser’



