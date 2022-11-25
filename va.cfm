
<!---
General Comments
================================
The purpose of this file is to scrape State Websites and collect license information.
We use this information to count required and elective credits based on the license template.
The name of this file sould be the iso 2 letter state code.

Below there are inline comments explaining how the calculations are done.
Each state might have different rules when doing these calculations.


http://dporweb.dpor.virginia.gov/LicenseLookup/LicenseDetail
http://dporweb.dpor.virginia.gov/LicenseLookup/Search
--->


<cfsetting requesttimeout="1200">
<cfoutput>
<cftry>
<h2>Virginia Test Scraper</h2>
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
		SELECT top 3 t.pk_trackerSearchID, t.trackerLicenseid, t.LicenseEmail,t.LicensePassword,t.renewalDate, lc.*,
				t.firstname,t.lastname
		FROM kirks_trackerSearch t

		INNER JOIN kirks_licenseScrape lc ON lc.pk_licenseid = t.fk_licenseScrapeid

		where lc.fk_stateID = 47 <!---this is the state ID--->

		<cfif previewSearch neq ""><!---this is added so that a specific license can be scraped--->
			and t.pk_trackerSearchID = <cfqueryparam value="#previewSearch#">
		<cfelse>
			<!---here we only collect licenses that have the information required to login and collect the information--->
			and t.trackerLicenseid != '' and t.trackerLicenseid is not Null
			order by newid()
		</cfif>
	</cfquery>
<cfelse>
	<cfquery name="getRecord">
		SELECT top 3 t.pk_trackerID, t.trackerLicenseid, t.LicenseEmail,t.LicensePassword,t.renewalDate, lc.*,
				en.firstname,en.lastname,en.pk_entityid
		FROM kirks_tracker t
		INNER JOIN mb_entity en ON en.pk_entityid = t.fk_entityid
		INNER JOIN kirks_licenseScrape lc ON lc.pk_licenseid = t.fk_licenseScrapeid

		where lc.fk_stateID = 47 <!---this is the state ID--->

		<cfif preview neq ""><!---this is added so that a specific license can be scraped--->
			and t.pk_trackerID = <cfqueryparam value="#preview#">
		<cfelse>
			<!---here we only collect licenses that have the information required to login and collect the information--->
			and t.trackerLicenseid != '' and t.trackerLicenseid is not Null
			order by newid()
		</cfif>
	</cfquery>
</cfif>


<cfif getRecord.recordcount eq 0>
	No license found
</cfif>


<table style="font-family: Gotham, 'Helvetica Neue', Helvetica, Arial, 'sans-serif'" cellspacing="1" cellpadding="4" bgcolor="grey">
	<cfloop query="getRecord">
		<tr bgcolor="darkgrey">
			<td>#getRecord.firstname# #getRecord.lastname#</td><!---name as found in the kazeli DB--->
			<td>#getRecord.l_dispname#</td><!---licence name as found in the kazeli DB--->
			<td>#getRecord.trackerLicenseid# (#dateformat(getRecord.renewalDate,'mm/dd/yyyy')#)</td><!---login licensceID and renual date as found in the kazeli DB--->
			<td>#getRecord.LicenseEmail#</td><!---login email as found in the kazeli DB--->
			<!---<td>#getRecord.LicensePassword#</td>password email as found in the kazeli DB--->
			<td>#getRecord.requiredParam#</td><!---parameters used to differentciate required credits--->
			<td>#getRecord.electiveParam#</td><!---parameters used to differentciate elective credits--->
		</tr>
		

		<cftry>
			<!---These parameters/url will be defined by Edward for each state so these will vary--->
			<cfhttp method="POST" url="https://ltxx.bunity.com/v1/va" result="resultText">
				<cfhttpparam type="header" name="Authorization" value="Basic a2F6ZWxpOj5zWzVaN11bRU4rayk7U2s=" />
				<cfhttpparam name="reg_number" type="formfield" value="#getRecord.trackerLicenseid#">
				<!---<cfhttpparam name="password" type="formfield" value="#getRecord.LicensePassword#">
				<cfhttpparam name="license_type" type="formfield" value="#getRecord.apiType#">--->
			</cfhttp>
			<cfset json = DeserializeJSON(resultText.Filecontent)>

			<cfif isdefined('json.error')>
				<!---check to see if error is defined in the data and if yes log the error below--->
				<cfset scrp_error = json.error>
				<tr bgcolor="white">
					<td colspan="6">
						Error: #scrp_error#
					</td>
				</tr>
				<!---log error the other parameters shoudl not change--->
				
				<cfif previewSearch neq "">
					<cfquery name="addData">
						update kirks_trackerSearch set
							scrp_date = #createODBCdatetime(now())#,
							scrp_result = <cfqueryparam value="-1">,
							scrp_error = <cfqueryparam value="#scrp_error#">
						where pk_trackerSearchID = <cfqueryparam value="#getRecord.pk_trackerSearchID#">
					</cfquery>
				<cfelse>
					<cfquery name="addData">
						update kirks_tracker set
							scrp_date = #createODBCdatetime(now())#,
							scrp_result = <cfqueryparam value="-1">,
							scrp_error = <cfqueryparam value="#scrp_error#">
						where pk_trackerID = <cfqueryparam value="#getRecord.pk_trackerID#">
					</cfquery>
				</cfif>
				
			<cfelse>
				<cfset req = getRecord.requiredCredits><!---required credits as defined by template--->
				<cfset elect = getRecord.electiveCredits><!---elective credits as defined by template--->
				<cfset scrp_name = json.name><!---users name as returned by scrape--->
				<cfset scrp_type = json.broker_type ?: ''><!---license type as returned by scrape--->
				<cftry>
                    <cfset test = json.expiration_date><!---expiration date as returned by scrape--->
                    <cfcatch><cfset specialMessage = 1></cfcatch>
                </cftry>
                <cfset scrp_expiration_date = json.expiration_date>
				<cfset scrp_topics = json.topics ?: []><!---topics taken as returned by scrape--->

				<!---Get the credits reported for the current license--->
				<cfset scrp_data = getTopics( scrp_topics, getRecord.requiredParam, getRecord.electiveParam ) />

				<tr bgcolor="white">
					<td>#scrp_name#</td>
					<td>#scrp_type#</td>
					<td>Exp: #dateformat(left(scrp_expiration_date,10),'mm/dd/yyyy')#</td>
					<td>&nbsp;</td>
					<td><strong>Req:</strong> #scrp_data.requiredCredits# of #req#</td>
					<td><strong>Elect:</strong> #scrp_data.electiveCredits# of #elect#</td>
				</tr>
				<tr bgcolor="white">
					<td colspan="4">&nbsp;</td>
					<td valign="top">

						<cfif arrayLen( scrp_data.r ) >
							<table border="1" style="font-family: Gotham, 'Helvetica Neue', Helvetica, Arial, 'sans-serif'; font-size: 10px;" cellspacing="0">
							<tr>
								<th>Required Topic</th>
								<th>Required</th>
								<th>Reported</th>
								<th>End date</th>
							</tr>
							<cfloop array="#scrp_data.r#" index="row">
								<tr>
									<td>#row.name#</td>
									<td>#row.requiredHours#</td>
									<td>#row.reportedHours#</td>
									<td>#row.endDate#</td>
									<!---<td>#scrp_topics[idx].provider ?: ""#</td>--->
								</tr>
							</cfloop>
							</table>
						</cfif>

						<cfif scrp_data.r.len() eq 0>
							No required topics found
						</cfif>
					</td>
					<td valign="top">
						<cfif arrayLen( scrp_data.e ) >
						  <table border="1" style="font-family: Gotham, 'Helvetica Neue', Helvetica, Arial, 'sans-serif'; font-size: 10px;" cellspacing="0">
						  <tr>
							<th>Elective Topic</th>
							<th>Required</th>
							<th>Reported</th>
							<th>End date</th>
						  </tr>
						  <cfloop array="#scrp_data.e#" index="row">
							<tr>
							  <td>#row.name#</td>
							  <td>#row.requiredHours#</td>
							  <td>#row.reportedHours#</td>
							  <td>#row.endDate#</td>
							  <!---<td>#scrp_topics[idx].provider ?: ""#</td>--->
							</tr>
						  </cfloop>
						  </table>
						</cfif>

						<cfif scrp_data.e.len() eq 0>
						  No elective topics found
						</cfif>
				  </td>
				</tr>

				<!---store values in the db --->
				
				<cfif previewSearch neq "">
					<cfquery name="addData">
						update kirks_trackerSearch set
							scrp_rCredits = <cfqueryparam value="#scrp_data.requiredCredits#">,
							scrp_eCredits = <cfqueryparam value="#scrp_data.electiveCredits#">,
							scrp_date = #createODBCdatetime(now())#,
							scrp_success_date = #createODBCdatetime(now())#,
							scrp_topics = <cfqueryparam value="#SerializeJSON(scrp_topics)#">,
							scrp_result = <cfqueryparam value="1">,<!---flagged as a good scrape--->
							scrp_error = <cfqueryparam value="">,
							scrp_expire = #createODBCdate(dateformat(left(scrp_expiration_date,10),'mm/dd/yyyy'))#
						where pk_trackerSearchID = <cfqueryparam value="#getRecord.pk_trackerSearchID#">
					</cfquery>
				<cfelse>
					<cfquery name="addData">
						update kirks_tracker set
							scrp_rCredits = <cfqueryparam value="#scrp_data.requiredCredits#">,
							scrp_eCredits = <cfqueryparam value="#scrp_data.electiveCredits#">,
							scrp_date = #createODBCdatetime(now())#,
							scrp_success_date = #createODBCdatetime(now())#,
							scrp_topics = <cfqueryparam value="#SerializeJSON(scrp_topics)#">,
							scrp_result = <cfqueryparam value="1">,<!---flagged as a good scrape--->
							scrp_error = <cfqueryparam value="">,
							scrp_expire = #createODBCdate(dateformat(left(scrp_expiration_date,10),'mm/dd/yyyy'))#
						where pk_trackerID = <cfqueryparam value="#getRecord.pk_trackerID#">
					</cfquery>
				</cfif>
			</cfif>

			<cfcatch>
				<cfif isDefined('specialMessage')>
                    <tr style="background-color:palevioletred">
                        <td colspan="6">Due to current State of Emergency, your license will be up for renewal 30 days after declaration has been lifted<br><!---<cfdump var="#cfcatch#">---></td>
                    </tr>
                <cfelse>
                    <tr style="background-color:palevioletred">
                        <td colspan="6">Error Pulling Data<br><!---<cfdump var="#cfcatch#">---></td>
                    </tr>
                </cfif>
				<!---If something above fails log in DB --->
				
				<cfif previewSearch neq "">
					<cfquery name="addData">
						update kirks_trackerSearch set
							scrp_date = #createODBCdatetime(now())#,
							scrp_result = <cfqueryparam value="-1">,
							scrp_error = <cfqueryparam value="Error Pulling Data">
						where pk_trackerSearchID = <cfqueryparam value="#getRecord.pk_trackerSearchID#">
					</cfquery>
				<cfelse>
					<cfquery name="addData">
						update kirks_tracker set
							scrp_date = #createODBCdatetime(now())#,
							scrp_result = <cfqueryparam value="-1">,
							scrp_error = <cfqueryparam value="Error Pulling Data">
						where pk_trackerID = <cfqueryparam value="#getRecord.pk_trackerID#">
					</cfquery>
				</cfif>

			</cfcatch>
		</cftry>

	</cfloop>
</table>

<cfcatch><cfdump var="#cfcatch#"></cfcatch>
</cftry>
</cfoutput>

<cffunction name="getTopics" returntype="struct" hint="Gets the credits reported and two separated arrays of required and elective topics" >
  <cfargument name="topics" type="array" required="true" hint="De array of topics" />
  <cfargument name="requiredParam" type="string" hint="The enconded list of required topics" default="" />
  <cfargument name="electiveParam" type="string" hint="The enconded list of elective topics" default="" />
  <cfscript>
  	var requiredTopics = [];
  	var electiveTopics = [];
  	var requiredArray = listToArray( arguments.requiredParam );
  	var electiveArray = listToArray( arguments.electiveParam );
  	var r = [];
  	var e = [];
  	var topic = "";
  	var requiredCredits = 0;
  	var electiveCredits = 0;

  	// Get an array of topic names from the requiredParam
  	for( topic in requiredArray ){
  		requiredTopics.append( listFirst( topic, '|' ) );
  	}

  	// Get an array of topic names from the electiveParam
    for( topic in electiveArray ){
      electiveTopics.append( listFirst( topic, '|' ) );
    }

    // Separate required and elective topics
    for( topic in arguments.topics ){
    	tempTopic = {
			name = topic.requirement,
			reportedHours = topic.hours_earned,
			requiredHours = topic.hours_required,
			endDate = dateFormat( left( topic.end_date, 10 ), 'mm/dd/yyyy' )
		  };
			if( arrayFindNocase( requiredTopics, topic.requirement ) ){
				// Add to the required topics
				r.append( duplicate( tempTopic ) );
			}else if( arrayFindNoCase( electiveTopics, topic.requirement ) ){
				// Add to elective topics
				e.append( duplicate( tempTopic ) );
			}else{
				// Not found in required or elective, then add to elective
				e.append( duplicate( tempTopic ) );
			}
    }

    // Get the total required credits
    for( topic in r ){
    	requiredCredits += topic.reportedHours;
    }
    // Get the total elective credits
    for( topic in e ){
      electiveCredits += topic.reportedHours;
    }

    return {
    	r = r,
    	e = e,
    	requiredCredits = requiredCredits,
    	electiveCredits = electiveCredits
    };
  </cfscript>
</cffunction>
