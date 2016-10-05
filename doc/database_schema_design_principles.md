# How to design the historical adress database ? #
For historical geocoding, we need a historical database of adresses.
Here are some thought on how we designed it.

## Context ##
Historical geodata are un-precise in several ways.
Data are temporally fuzzy, spatially fuzzy, and incomplete.
Moreover, tranckign the data source and creation is important.
The available dat ais mainly road network with road name manually entered by historians,
for a set of maps.
We have very few data available about building numbering. 
We also have data from historical sources that can prove that a given numbering in a given road existed at a given date, 
without precision about this numbering localisation.

## Requirement ##
Requirements :
 - we need a generic solution that works for the entire city of Paris (and can be extended to other french places), for adresses between 
1810 and today.
 - extensibility : it should be easy to add other data from other historical map
 - editability : the database should be relationnaly well protected to avoid data corruption
 - trackability : the data sources, and successive modification, should be stored.
 - scarcity : some input data are sparse spatially or temporally, hence the model has to allow this
 
## Overall solution ##
We center our modelling on road axis with semantic information (name).
We do not force to use topology on road axis because it is not strictly required for geocoding,
and because it greatly increases the complexity (in perticular for editing).
Buidling numbers are stored separately to raod axis, and can be linked to one or several axis.

We use the postgres inheritance mechanism to ensure felxibility and extensibility.

## Detailed solution ##
