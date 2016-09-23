# -*- coding: utf-8 -*-
"""
Created on Fri Aug 12 09:51:39 2016

@author: remi
analysing the distribution of building number in paris
"""

# get data : connect to base and retrieve data
# proper formating of data
import numpy as np

def connect_to_database():
    """ connect to database and return, for each road, the building number + distance between numbers
    format: 
    result[0] : one row 
    result[0][0] : street name (texte)
    result[0][1] : side of the street (texte)
    result[0][2] : gids of each number (array int)
    result[0][3] : number (array float)
    result[0][4] : dist to next number (array float)
    
    
    """
    import psycopg2
    connection_string = """host=localhost dbname=test_bdadresse user=postgres password=postgres port=5434""" 
    conn = psycopg2.connect(connection_string)
    cur = conn.cursor()  
    query = """
    SELECT nom_voie, cote
        , array_agg(gid ORDER BY numf asc) AS gids
        , array_agg(numf ORDER BY numf asc) AS numfs
        , array_agg(dist_to_suivant ORDER BY numf asc) as dists
	FROM num_with_next
	WHERE est_contigue is true AND dist_to_suivant >1  
	GROUP BY nom_voie, cote  
	ORDER BY nom_voie, cote  
    """
    cur.execute(query)
    r_query = cur.fetchall() 
    
    cur.close()
    conn.close()  
    return r_query


def format_data( data_fromdatabase ):
    import numpy as np
    streets_name = []
    numbers_side = []
    numbers_gid = []
    numbers = []
    numbers_dist = []
    
    for row in data_fromdatabase:
        streets_name.append(row[0])
        numbers_side.append(row[1])
        numbers_gid.append(np.array(row[2]))
        numbers.append(np.array(row[3]))
        numbers_dist.append(np.array(row[4]))
  
    return streets_name, numbers_side, np.array(numbers_gid) \
        , np.array(numbers), np.array(numbers_dist) 


def plot_histogram(x, nbins, label_): 
    #matplotlib.use('Agg') 
    import pylab as P
    n, bins, patches = P.hist(x, bins = nbins , normed=1, histtype='bar',
                           # color=['Blue', 'Green', 'Red']  
                           label=label_ )
def plot_error_bar_for_given_number_of_house_number(selected_streets_house_number_dist):
    #for each x, compute median and stddev
    import matplotlib.pyplot as plt 
    s_m = np.median(selected_streets_house_number_dist,0)
    s_stddev = np.std(selected_streets_house_number_dist,0)
    y = np.arange(0,selected_streets_house_number_dist.shape[1],1)
    # plot
    
    plt.errorbar(y, s_m, yerr=s_stddev, fmt='-o')
    
    
    
    
def main():
    output_screen_folder = '/media/sf_RemiCura/PROJETS/belleepoque/historical_geocoding/results/analysing_distance_between_successive_numbers/'
    #load data from database
    r_query = connect_to_database() 
    #format data into handy array
    streets_name, numbers_side, numbers_gid, numbers, numbers_dist = \
        format_data( r_query )
    
    #plot histogram of possible street numler of numbers
    number_of_house_number = np.array([len(t) for t in numbers_gid])
    print(len(number_of_house_number))
    
    print(np.median(number_of_house_number))
    
    # plot_histogram(number_of_house_number[(number_of_house_number>5) & (number_of_house_number<100) ], 50, 'possible number of house number')
    #plot histogram of possible numbers : 
    all_numbers = np.concatenate(numbers) 
    # plot_histogram(all_numbers, 500, 'hist of dist')
    
    #plot histogramm of possible distance
    all_numbers_dist = np.concatenate(numbers_dist) 
    # plot_histogram(all_numbers_dist[(all_numbers_dist>3) & (all_numbers_dist< 100)], 100, 'hist of dist')
    
    #categorise street by number of house number :
    # for few number of house number, plot all dist of this street
    
    selected_streets_house_number_dist = np.array([t for t in numbers_dist if len(t) == 6])
 
    
    # plot the selected street house number
    import matplotlib.pyplot as plt
    # plt.plot(s_m)
    plot_error_bar_for_given_number_of_house_number(selected_streets_house_number_dist)
    
    for i in range(3,20):
        plt.close("all")
        selected_streets_house_number_dist = np.array([t for t in numbers_dist if len(t) == i])
        plot_error_bar_for_given_number_of_house_number(selected_streets_house_number_dist)
        plt.savefig(output_screen_folder+'distribution_of_distance_for_'+str(i)+'_numbers.png', bbox_inches='tight')
        plt.close("all")
      
    
    
        
        
main()