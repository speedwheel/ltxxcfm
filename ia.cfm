
<cfsetting requesttimeout="1200">
<cfoutput>
<cftry>

<h2>Iowa (IA) Test Scraper</h2>
<cfparam name="preview" default="">
<cfparam name="previewSearch" default="">

<!---
This query will retrive all users that need to be scraped.
To find the value of the stateID you can go to this url and select it in state in the dropdown.
The ID of the state is next to the state name in the dropdown.

Each state might require different parameters for scraping Maryland we need password and licenseID.
We are current have 3 fields for this in future we could add more the DB field names are:
	trackerLicenseid
	LicenseEmail
	LicensePassword
--->

<cfif previewSearch neq "">
	<cfquery name="qryRecord">
		SELECT top 3 
		t.pk_trackerSearchID, 
		t.trackerLicenseid, 
		t.LicenseEmail,
		t.LicensePassword,
		t.renewalDate, 

		lc.*,
		
		t.firstname,
		t.lastname

		FROM kirks_trackerSearch t
		INNER JOIN kirks_licenseScrape lc ON lc.pk_licenseid = t.fk_licenseScrapeid

		WHERE lc.fk_stateID = 16 <!---this is the state ID--->

		<cfif previewSearch neq ""><!---this is added so that a specific license can be scraped--->
			AND t.pk_trackerSearchID = <cfqueryparam value="#previewSearch#" cfsqltype="cf_sql_integer">
		<cfelse>
			<!---here we only collect licenses that have the information required to login and collect the information--->
			AND t.trackerLicenseid != '' AND t.trackerLicenseid IS NOT NULL
			ORDER BY NEWID()
		</cfif>
	</cfquery>
<cfelse>
	<cfquery name="qryRecord">
		SELECT top 3 
		t.pk_trackerID, 
		t.trackerLicenseid, 
		t.LicenseEmail,
		t.LicensePassword,
		t.renewalDate, 

		lc.*,
		
		en.firstname,
		en.lastname,
		en.pk_entityid

		FROM kirks_tracker t
		INNER JOIN mb_entity en ON en.pk_entityid = t.fk_entityid
		INNER JOIN kirks_licenseScrape lc ON lc.pk_licenseid = t.fk_licenseScrapeid

		WHERE lc.fk_stateID = 16 <!---this is the state ID--->

		<cfif preview neq ""><!---this is added so that a specific license can be scraped--->
			AND t.pk_trackerID = <cfqueryparam value="#preview#" cfsqltype="cf_sql_integer">
		<cfelse>
			<!---here we only collect licenses that have the information required to login and collect the information--->
			AND t.trackerLicenseid != '' AND t.trackerLicenseid IS NOT NULL
			ORDER BY NEWID()
		</cfif>
	</cfquery>
</cfif>

<cfif qryRecord.recordcount eq 0>
	No license found <cfabort>
</cfif>

<table style="font-family: Gotham, 'Helvetica Neue', Helvetica, Arial, 'sans-serif'" cellspacing="1" cellpadding="4" bgcolor="grey">
	<cfloop query="qryRecord">
		<tr bgcolor="darkgrey">
			<td>#qryRecord.firstname# #qryRecord.lastname#</td><!---name as found in the kazeli DB--->
			<td>#qryRecord.l_dispname#</td><!---licence name as found in the kazeli DB--->
			<td>#qryRecord.trackerLicenseid# (#qryRecord.renewalDate#)</td><!---login licensceID and renual date as found in the kazeli DB--->
			<td>#qryRecord.LicenseEmail#</td><!---login email as found in the kazeli DB--->
			<td>#qryRecord.LicensePassword#</td><!---password email as found in the kazeli DB--->
		</tr>
		
		<cftry>
			<cfif Len(qryRecord.trackerLicenseid) LT 1>
				<cfthrow message="Invalid license information">
			</cfif>
			
			<!---These parameters/url will be defined by Edward for each state so these will vary--->
			<cfhttp method="POST" url="https://ltxx.bunity.com/v1/ia" result="resultText">
				<cfhttpparam type="header" name="Authorization" value="Basic a2F6ZWxpOj5zWzVaN11bRU4rayk7U2s=">
				<cfhttpparam name="reg_number" type="formfield" value="#qryRecord.trackerLicenseid#">
			</cfhttp>

			<cfset json = DeserializeJSON(resultText.Filecontent)>
			
			<cfif structKeyExists(json,"error")>
				<!---check to see if error is defined in the data and if yes log the error below--->
				<cfset scrp_error = json.error>
				<tr bgcolor="white">
					<td colspan="10">
						Error: #scrp_error#
					</td>
				</tr>
				<!---log error the other parameters shoudl not change--->
				<cfif previewSearch neq "">
					<cfquery name="addData">
						UPDATE kirks_trackerSearch SET
							scrp_date = #createODBCdatetime(now())#,
							scrp_result = <cfqueryparam value="-1">,
							scrp_error = <cfqueryparam value="#scrp_error#" cfsqltype="cf_sql_varchar">
						WHERE pk_trackerSearchID = <cfqueryparam value="#qryRecord.pk_trackerSearchID#" cfsqltype="cf_sql_integer">
					</cfquery>
				<cfelse>
					<cfquery name="addData">
						UPDATE kirks_tracker SET
							scrp_date = #createODBCdatetime(now())#,
							scrp_result = <cfqueryparam value="-1">,
							scrp_error = <cfqueryparam value="#scrp_error#" cfsqltype="cf_sql_varchar">
						WHERE pk_trackerID = <cfqueryparam value="#qryRecord.pk_trackerID#" cfsqltype="cf_sql_integer">
					</cfquery>
				</cfif>
					
			<cfelse>
			
				<tr bgcolor="white">
					<td>#json.name#</td>
					<td>#json.license_type#</td>
					<td>#json.license# Exp: #dateformat(left(json.expiration_date,10),'mm/dd/yyyy')#</td>
					<td colspan="2">&nbsp;</td>
				</tr>
				
				<!---store values in the db --->
				<cfif previewSearch neq "">
					<cfquery name="addData">
						UPDATE kirks_trackerSearch SET
							scrp_date = #createODBCdatetime(now())#,
							scrp_success_date = #createODBCdatetime(now())#,
							scrp_result = <cfqueryparam value="1">,<!---flagged as a good scrape--->
							scrp_error = <cfqueryparam value="" cfsqltype="cf_sql_varchar">,
							scrp_expire = #createODBCdate(dateformat(left(json.expiration_date, 10), 'mm/dd/yyyy'))#
						WHERE pk_trackerSearchID = <cfqueryparam value="#qryRecord.pk_trackerSearchID#" cfsqltype="cf_sql_integer">
					</cfquery>
				<cfelse>
					<cfquery name="addData">
						UPDATE kirks_tracker SET
							scrp_date = #createODBCdatetime(now())#,
							scrp_success_date = #createODBCdatetime(now())#,
							scrp_result = <cfqueryparam value="1">,<!---flagged as a good scrape--->
							scrp_error = <cfqueryparam value="" cfsqltype="cf_sql_varchar">,
							scrp_expire = #createODBCdate(dateformat(left(json.expiration_date, 10), 'mm/dd/yyyy'))#
						WHERE pk_trackerID = <cfqueryparam value="#qryRecord.pk_trackerID#" cfsqltype="cf_sql_integer">
					</cfquery>
				</cfif>
					
				
			</cfif>
			
			<cfcatch type="any">
				<tr style="background-color:palevioletred">
					<td colspan="5">Error Pulling Data<br><cfdump var="#cfcatch#"></td>
				</tr>
				<!---If something above fails log in DB --->
				<cfif previewSearch neq "">
					<cfquery name="addData">
						UPDATE kirks_trackerSearch SET
							scrp_date = #createODBCdatetime(now())#,
							scrp_result = <cfqueryparam value="-1">,
							scrp_error = <cfqueryparam value="Error Pulling Data" cfsqltype="cf_sql_varchar">
						WHERE pk_trackerSearchID = <cfqueryparam value="#qryRecord.pk_trackerSearchID#" cfsqltype="cf_sql_integer">
					</cfquery>
				<cfelse>
					<cfquery name="addData">
						UPDATE kirks_tracker SET
							scrp_date = #createODBCdatetime(now())#,
							scrp_result = <cfqueryparam value="-1">,
							scrp_error = <cfqueryparam value="Error Pulling Data" cfsqltype="cf_sql_varchar">
						WHERE pk_trackerID = <cfqueryparam value="#qryRecord.pk_trackerID#" cfsqltype="cf_sql_integer">
					</cfquery>
				</cfif>
					
			
			</cfcatch>
		</cftry>
	</cfloop>

</table>


<cfcatch type="any"><cfdump var="#cfcatch#"></cfcatch>
</cftry>
</cfoutput>