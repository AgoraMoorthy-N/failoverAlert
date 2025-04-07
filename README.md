# failoverAlert
To get failover alert whenever a SQL instance failover from primary to secondary in a Always ON availability.

Step -1 : First create the Failover table to track and store the failover data internally.
          Execute "[dbo].[Failover_Details] table creation" sql file
Step -2 : Update Failover details with latest failover data by executing the below sql file.
          Execute "Updating Failover Table with Current data" sql file
Step -3 : Execute below two store procedure inside your database,in this case DBA_InternalDB
          "Usp_Replica_Failover_Alert_SP"
          "usp_Updating_Failover_Details_Table" 
Step -4 : Create the Job Adhoc_Part_Of_Failover_Alert to run "usp_Updating_Failover_Details_Table" SP to update failover details table every 5 minutes.
          Execute "Part of adhoc failover alert job" sql file
Step -5 : Create the Job **DBA_Failover_Alert to run "Usp_Replica_Failover_Alert_SP" SP to send mail to DBA's with required details.
          Execute "Failover alert" sql file.

Working :

With current data inserted in failover details table, Store Procedure usp_Updating_Failover_Details_Table will run every 5 minutes through "Part of adhoc failover alert job"

The SP is designed to get and compare the current data count and internally tracked dbo.failover details table count.

If current count of failover is higher than dbo.failover details table count,then **DBA_Failover_Alert Job will be triggered, which will in turn fire the store procedure "Usp_Replica_Failover_Alert_SP" which fetches the required data in HTML format and send it to DBA configured mail profile.

Cost :

Data has to be stored internally to fire the alert alert,since we need older data to compare and send alerts.



