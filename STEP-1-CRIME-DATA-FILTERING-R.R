# Crime rates
# Install and load necessary libraries
library(tidyverse)
library(dplyr)
library(readr)
library(arrow)
library(lubridate)

# 1.Load the CSV file using read_csv (it's faster than base read.csv)
crime_data <- read_csv("Crimes_-_2001_to_Present_20240909.csv")
# 2. Load Spatial Data for Beat-to-District Mapping
beat_map_post_2012 <- st_read("geo_export_0e4cec96-27db-4986-aa31-6ef467c22c26.shp")

# 3. Check for unique unit numbers in both spatial files
unique_post_2012 <- unique(beat_map_post_2012$district)
print(unique_pre_2012)

# 4. Convert District column to numeric (removing any non-numeric entries)
crime_data$District <- as.numeric(crime_data$District)

# 5. Use sprintf to format districts as three digits
crime_data$District <- sprintf("%03d", crime_data$District)

# 6. Verify the result by printing unique districts
unique_dist <- unique(crime_data$District)
print(unique_dist)

# 7. Convert 'Date' column to Date-Time format using lubridate
crime_data <- crime_data %>%
  mutate(Date = mdy_hms(Date))  # Convert the 'Date' column to datetime

# 8. Filter the data for records from 2002 onwards
crime_data_filtered <- crime_data %>%
  filter(Date >= as.Date("2004-01-01") & Date <= as.Date("2020-12-31"))

# 9. Select the necessary columns
crime_clean <- crime_data_filtered %>%
  select('Date', 'ID', 'Beat', 'District', 'Ward', 'Arrest', 'Latitude', 'Longitude', 'Primary Type')

# 10. Check if there are any NA values in 'District'
sum(is.na(crime_clean$District))

# 11. Define the list of districts (include old and new beat structure to make sure, no districts are missed out on)
districts <- c('001', '002', '003', '004', '005', '006', '007', '008', '009', 
              '010', '011', '012', '013', '014', '015', '016', '017', '018', '019', '020', '021', '022', '023', '024', '025')
# 12. Filter assignment data by relevant patrol units
crime_units <- crime_clean %>%
  filter(District %in% districts)

# 13. Define the mapping from deprecated districts to post-2012 equivalents [to make sure it refelcts actual currrent beats]
district_mapping <- c("013" = "012", "021" = "002", "023" = "019")

# 14. Recode the deprecated districts in the crime_filtered data
crime_units <- crime_units %>%
  mutate(District = recode(District, !!!district_mapping))

# 15. Verify that the recoding worked correctly
unique_dist_recode <- unique(crime_units$District)
print(unique_dist_recode)
# 16. Categorize 'Primary Type' into broader crime categories
crime_units <- crime_units %>%
  mutate(Crime_Category = case_when(
    `Primary Type` %in% c('ROBBERY', 'CRIMINAL SEXUAL ASSAULT', 'OFFENSE INVOLVING CHILDREN', 'CRIM SEXUAL ASSAULT',
                          'ASSAULT', 'SEX OFFENSE', 'BATTERY', 'HOMICIDE', 'STALKING', 
                          'KIDNAPPING', 'INTIMIDATION') ~ 'Violent Crime',
    
    `Primary Type` %in% c('THEFT', 'DECEPTIVE PRACTICE', 'BURGLARY', 'MOTOR VEHICLE THEFT', 
                          'CRIMINAL TRESPASS', 'CRIMINAL DAMAGE', 'ARSON') ~ 'Property Crime',
    
    `Primary Type` %in% c('NARCOTICS', 'OTHER NARCOTIC VIOLATION') ~ 'Drug-Related Crime',
    
    `Primary Type` %in% c('WEAPONS VIOLATION', 'LIQUOR LAW VIOLATION', 'PUBLIC PEACE VIOLATION', 
                          'PROSTITUTION', 'GAMBLING', 'INTERFERENCE WITH PUBLIC OFFICER', 'OBSCENITY', 'PUBLIC INDECENCY') ~ 'Public Order Crime',
    
    `Primary Type` %in% c('NON-CRIMINAL', 'NON - CRIMINAL', 'NON-CRIMINAL (SUBJECT SPECIFIED)', 
                          'CONCEALED CARRY LICENSE VIOLATION', 'HUMAN TRAFFICKING', 'OTHER OFFENSE') ~ 'Administrative or Non-Criminal',
    
    TRUE ~ 'Other'  # Catch-all for uncategorized crimes
  ))





# 17. Export the cleaned DataFrame - will be used for the second step and preprocessing in Python
library(arrow)
write_parquet(crime_units, 'crimeunits2409.parquet')
