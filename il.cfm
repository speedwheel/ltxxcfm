
<cfsetting requesttimeout="1200">
<cfoutput>
<cftry>

<h2>Illinois (IL) Test Scraper</h2>
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
	<cfquery name="getRecord">
		SELECT top 4 
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

		WHERE lc.fk_stateID = 14 <!---this is the state ID--->

		<cfif previewSearch neq ""><!---this is added so that a specific license can be scraped--->
			AND t.pk_trackerSearchID = <cfqueryparam value="#previewSearch#" cfsqltype="cf_sql_integer">
		<cfelse>
			<!---here we only collect licenses that have the information required to login and collect the information--->
			AND t.trackerLicenseid != '' AND t.trackerLicenseid IS NOT NULL
			ORDER BY NEWID()
		</cfif>
	</cfquery>
<cfelse>
	<cfquery name="getRecord">
		SELECT top 4 
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

		WHERE lc.fk_stateID = 14 <!---this is the state ID--->

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
			<!---These parameters/url will be defined by Edward for each state so these will vary--->
			<cfhttp method="POST" url="https://ltxx.bunity.com/v1/il" result="resultText">
				<cfhttpparam type="header" name="Authorization" value="Basic a2F6ZWxpOj5zWzVaN11bRU4rayk7U2s=">
				<cfhttpparam name="reg_number" type="formfield" value="#qryRecord.trackerLicenseid#">

				<cfif Len(qryRecord.apiType) GT 1>
					<cfhttpparam name="prefix" type="formfield" value="#qryRecord.apiType#">
				</cfif>
			</cfhttp>
			
			<cfset json = DeserializeJSON(resultText.Filecontent)>
			<!--- <cfdump var="#json#" abort="true" top="2"> --->
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
					<td>#json["name"]#</td>
					<td>#dateformat(left(json["issued_date"], 10), 'mm/dd/yyyy')#</td>
					
					<td>
						<cfif structKeyExists(json ,"license_type")>
							#json["license_type"]#
						</cfif>
					</td>
					
					<td>Exp: #dateformat(left(json.expiration_date,10),'mm/dd/yyyy')#</td>

					<cftry>
						<cfset scrp_expiration_date = dateformat(left(json.expiration_date,10),'yyyy-mm-dd') />
						<cfcatch><cfset scrp_expiration_date = "" /></cfcatch>
					</cftry>


					<cfif structKeyExists(json, "topics") and isArray(json.topics) and arrayLen(json.topics) gt 0>
						<td colspan="2">
							<table>
								<tr>
									<th>Name</th>
									<th>Type</th>
									<th>ID</th>
									<th>Hours</th>
									<th>Date</th>
								</tr>
								<cfloop from="1" to="#ArrayLen(json.topics)#" index="i">
									<cfset item = json.topics[i]>
									<tr>
										<td>#item.name#</td>
										<td><cftry>#item.type#<cfcatch></cfcatch></cftry></td>
										<td>#item.id#</td>
										<td>#item.hours#</td>
										<td>#dateformat(left(item.date, 10), 'mm/dd/yyyy')#</td>
									</tr>
								</cfloop>
							</table>
						</td>
					<cfelse>
						<td colspan="2">&nbsp;</td>
					</cfif>
				</tr>

				<!---store values in the db --->
				<cfif structKeyExists(json, "topics") and isArray(json.topics) and arrayLen(json.topics) gt 0>
					<cfset topicsTotal = getTopicsTotal(json.topics, scrp_expiration_date)>
				</cfif>	

				<cfif previewSearch neq "">
					<cfquery name="addData">
						UPDATE kirks_trackerSearch SET
							scrp_date = #createODBCdatetime(now())#,
							scrp_success_date = #createODBCdatetime(now())#,
							
							<cfif structKeyExists(json, "topics") and isArray(json.topics) and arrayLen(json.topics) gt 0>
								scrp_rCredits = <cfqueryparam value="#topicsTotal.Req#">,
								scrp_eCredits = <cfqueryparam value="#topicsTotal.Elec#">,
								scrp_topics = <cfqueryparam value="#SerializeJSON(json.topics)#" cfsqltype="cf_sql_varchar">,
							</cfif>

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
							
							<cfif structKeyExists(json, "topics") and isArray(json.topics) and arrayLen(json.topics) gt 0>
								scrp_rCredits = <cfqueryparam value="#topicsTotal.Req#">,
								scrp_eCredits = <cfqueryparam value="#topicsTotal.Elec#">,
								scrp_topics = <cfqueryparam value="#SerializeJSON(json.topics)#" cfsqltype="cf_sql_varchar">,
							</cfif>

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

<cffunction name="getTopicsTotal" returntype="struct" hint="Gets the total hours of Core and elective topics" >
	<cfargument name="topics" type="array" required="true" hint="Array of topics" />
	<cfargument name="expiration_date" type="any" required="true"/>
	<cfscript>

		var loc = {"Req":0, "Elec":0, "totalUnits":0};
		var validAfterDate = now();
	    if(arguments.expiration_date != ""){
	      validAfterDate = dateAdd('yyyy',-2,arguments.expiration_date);
	    }
	    validAfterDate = dateformat(validAfterDate,'yyyy-mm-dd');

		var totalUnits = 0;
		for( var topic in arguments.topics ){
			if(topic.date >= validAfterDate){
				if (isDefined("topic.type")){
					if(topic.type EQ "Core"){
						loc.Req += topic.hours;
						totalUnits += topic.hours;
					}
					else if(topic.type EQ  "Elective"){
						loc.Elec += topic.hours;
						totalUnits += topic.hours;
					}
				}
			}
		}

		loc.totalUnits = totalUnits;

		return loc;
	</cfscript>
</cffunction>
