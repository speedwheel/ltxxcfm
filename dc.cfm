
<!---
General Comments
================================
The purpose of this file is to scrape State Websites and collect license information.
We use this information to count required and elective credits based on the license template.
The name of this file sould be the iso 2 letter state code.

Below there are inline comments explaining how the calculations are done.
Each state might have different rules when doing these calculations.
--->


<cfsetting requesttimeout="1200">
<cfoutput>
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

      where lc.fk_stateID = 9<!---this is the state ID--->

      <cfif previewSearch neq ""><!---this is added so that a specific license can be scraped--->
        and t.pk_trackerSearchID = <cfqueryparam value="#previewSearch#">
      <cfelse>
        <!---here we only collect licenses that have the information required to login and collect the information--->
        and t.trackerLicenseid != '' and t.trackerLicenseid is not Null
        and t.LicensePassword != '' and t.LicensePassword is not Null
        order by t.LicenseEmail, newid()
      </cfif>
    </cfquery>
<cfelse>
  <cfquery name="getRecord">
    SELECT top 3 t.pk_trackerID, t.trackerLicenseid, t.LicenseEmail,t.LicensePassword,t.renewalDate, lc.*,
        en.firstname,en.lastname,en.pk_entityid
    FROM kirks_tracker t
    INNER JOIN mb_entity en ON en.pk_entityid = t.fk_entityid
    INNER JOIN kirks_licenseScrape lc ON lc.pk_licenseid = t.fk_licenseScrapeid

    where lc.fk_stateID = 9<!---this is the state ID--->

    <cfif preview neq ""><!---this is added so that a specific license can be scraped--->
      and t.pk_trackerID = <cfqueryparam value="#preview#">
    <cfelse>
      <!---here we only collect licenses that have the information required to login and collect the information--->
      and t.trackerLicenseid != '' and t.trackerLicenseid is not Null
      and t.LicensePassword != '' and t.LicensePassword is not Null
      order by t.LicenseEmail, newid()
    </cfif>
  </cfquery>
</cfif>

<html>
	<head>
    <meta charset="utf-8" />
    <title>District of Columbia</title>
    <meta http-equiv="X-UA-Compatible" content="IE=edge">
    <meta content="width=device-width, initial-scale=1" name="viewport" />

    <link href="https://stackpath.bootstrapcdn.com/bootstrap/4.3.1/css/bootstrap.min.css" rel="stylesheet" integrity="sha384-ggOyR0iXCbMQv3Xipma34MD+dH/1fQ784/j6cY/iJTQUOhcWr7x9JvoRxT2MZw1T" crossorigin="anonymous">


  </head>


  <body>
    <div class="shadow p-3 mb-5 bg-white rounded">
    	<h2>District of Columbia</h2>
    </div>

    <cfif getRecord.recordcount eq 0>
    	<div class="container">
    		<p class="alert-warning">No licences</p>
    	</div>

    <cfelse>
      <cfloop query="getRecord">
      <div class="container-fluid border border-primary mb-3 pb-1">

            <cftry>
              <!---These parameters/url will be defined by Edward for each state so these will vary--->
              <cfhttp method="POST" url="https://ltxx.bunity.com/v1/dc" result="resultText">
                <cfhttpparam type="header" name="Authorization" value="Basic a2F6ZWxpOj5zWzVaN11bRU4rayk7U2s=" />
                <cfhttpparam name="reg_number" type="formfield" value="#getRecord.trackerLicenseid#">
                <cfhttpparam name="password" type="formfield" value="#getRecord.LicensePassword#">
                <!---<cfhttpparam name="license_type" type="formfield" value="#getRecord.apiType#">--->
              </cfhttp>

              <!---Deserialize the response from the call to the API--->
              <cfset json = DeserializeJSON(resultText.Filecontent)>

              <cfif isdefined('json.error')>
                <!---check to see if error is defined in the data and if yes log the error below--->
                <cfset scrp_error = json.error>
                <p class="alert-danger">Error: #scrp_error#</p>

                <!---log error the other parameters shoudl not change--->
                <cfif previewSearch neq "">
				
				<cfelse>
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
                <!---If the name does not exist in the result, continue to the next row--->
                <cfif isNull( json.name )>
                  <cfset json.name = "" />
                  <cfset json.topics = [] />
                </cfif>
                <!---<cfdump var="#json#">--->
                <cfif structKeyExists( json, 'license' ) and structKeyExists( json.license, 'expiration_date' ) >
                  <cfset scrp_expiration_date = left( json.license.expiration_date,10)> <!---expiration date as returned by scrape--->
                <cfelse>
                  <cfset scrp_expiration_date = "" />
                </cfif>
                

                <cfset scrp_name = json.name><!---users name as returned by scrape--->
                <cfset scrp_topics = json.topics ?: []><!---topics taken as returned by scrape--->

                <!---Get the credits reported for the current license--->
                <cfset scrp_data = getTopics( scrp_topics, getRecord.requiredCredits, getRecord.electiveCredits, scrp_expiration_date  ) />
                <div class="row">
                  <div class="col-md-12 bg-secondary text-light">
                    <h4>#getRecord.firstname# #getRecord.lastname#</h4>
                    <h5>#getRecord.l_dispname#</h5>
                    <h5>#getRecord.trackerLicenseid# (#dateformat(scrp_expiration_date,'mm/dd/yyyy')#)</h5>
                    <h5>#getRecord.LicenseEmail#</h5>
                  </div>
                  <div class="col-md-12">
                  	<h5>
                        <cfif scrp_topics.len() eq 0> No </cfif>Topics
                    </h5>
                    <cfif scrp_topics.len()>
					 <table class="table table-sm">
                        <tr>
                          <th>Completion Date</th>
                          <th>Course name</th>
                          <th>Units</th>
                        </tr>
                        <cfloop array="#scrp_topics#" index="topic">
                        	<tr>
                        		<td>
                        			<cftry>#dateformat(left( topic.course_completion_date,10),'mm/dd/yyyy')#<cfcatch>err</cfcatch></cftry>
                        		</td>
                        		<td>
									<cftry>#topic.name#<cfcatch>err</cfcatch></cftry>
                        		</td>
                        		<td>
                        			<cftry>#topic.units#<cfcatch>err</cfcatch></cftry>
                        		</td>
                        	</tr>
                        </cfloop>
                      </table>

                      <div class="row">
                        <div class="col-md-12 text-center">
                          
						  <span type="button" class="btn btn-primary">
                            Collected Required Credits 
							<span class="badge badge-light">
								<cfif isDefined('scrp_data.requiredCredits')>
									#scrp_data.requiredCredits#
								<cfelse>
									0
								</cfif>
							</span>
                          </span>
						  
						  
						  <span type="button" class="btn btn-primary">
                            Collected Elective Credits 
							<span class="badge badge-light">
								<cfif isDefined('scrp_data.electiveCredits')>
									#scrp_data.electiveCredits#
								<cfelse>
									0
								</cfif>
							</span>
                          </span>
						  
						  
						  
						  <span type="button" class="btn btn-primary">
                            Total topics <span class="badge badge-light">#scrp_data.totalTopics#</span>
                          </span>
                          <span type="button" class="btn btn-primary">
                            Total Units <span class="badge badge-light">#scrp_data.totalUnits#</span>
                          </span>
                        </div>
                      </div>
                    </cfif>
                  </div>
                </div>
				
                <!---store values in the db --->
                <cfif previewSearch neq "">
				
				<cfelse>
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
                      <cfif scrp_expiration_date eq "">
                      scrp_expire = <cfqueryparam cfsqltype="CF_SQL_DATE" null="Yes"> 
                    <cfelse>
                      scrp_expire = #createODBCdate(scrp_expiration_date)#
                    </cfif>
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
                      <cfif scrp_expiration_date eq "">
                      scrp_expire = <cfqueryparam cfsqltype="CF_SQL_DATE" null="Yes"> 
                    <cfelse>
                      scrp_expire = #createODBCdate(scrp_expiration_date)#
                    </cfif>
                    where pk_trackerID = <cfqueryparam value="#getRecord.pk_trackerID#">
                  </cfquery>
                </cfif>
              </cfif>

            <cfcatch name="e">
              <p class="alert-danger">Error Pulling Data</p>
              <br>
              <cfdump var="#e#">

              <!---If something above fails log in DB --->
              <cfif previewSearch neq "">
				
				<cfelse>
              <cfif previewSearch neq "">
                <cfquery name="addData">
                  update kirks_trackerSearch set
                    scrp_date = #createODBCdatetime(now())#,
                    scrp_result = <cfqueryparam value="-1">,
                    scrp_error = <cfqueryparam value="Error Pulling Data">
                  where pk_trackerSearchID = <cfqueryparam value="#getRecord.pk_trackerSearchID#" />
                </cfquery>
              <cfelse>
                <cfquery name="addData">
                  update kirks_tracker set
                    scrp_date = #createODBCdatetime(now())#,
                    scrp_result = <cfqueryparam value="-1">,
                    scrp_error = <cfqueryparam value="Error Pulling Data">
                  where pk_trackerID = <cfqueryparam value="#getRecord.pk_trackerID#" />
                </cfquery>
              </cfif>
        </cfif>
            </cfcatch>
          </cftry>


      </div>
      </cfloop>
    </cfif>

    	<script src="https://stackpath.bootstrapcdn.com/bootstrap/4.3.1/js/bootstrap.min.js" integrity="sha384-JjSmVgyd0p3pXB1rRibZUAYoIIy6OrQ6VrjIEaFf/nJGzIxFDsf4x0xIM+B07jRM" crossorigin="anonymous"></script>
    	<script src="https://stackpath.bootstrapcdn.com/bootstrap/4.3.1/js/bootstrap.bundle.min.js" integrity="sha384-xrRywqdh3PHs8keKZN+8zzc5TX0GRTLCcmivcbNJWm2rs5C8PRhcEn3czEjhAO9o" crossorigin="anonymous"></script>
    </body>
</html>

</cfoutput>

<cffunction name="getTopics" returntype="struct" hint="Gets the credits reported and two separated arrays of required and elective topics" >
  <cfargument name="topics" type="array" required="true" hint="De array of topics" />
  <cfargument name="reqNeeded" type="any" required="true"/>
  <cfargument name="eleNeeded" type="any" required="true"/>
  <cfargument name="expiration_date" type="any" required="true"/>

<cftry>	
  <cfscript>
    var validAfterDate = now();
    if(arguments.expiration_date != ""){
      validAfterDate = dateAdd('yyyy',-2,arguments.expiration_date);
    }
    validAfterDate = dateformat(validAfterDate,'yyyy-mm-dd');

    var totalUnits = 0;
    for( var topic in arguments.topics ){
    	if(topic.course_completion_date >= validAfterDate){
        totalUnits += topic.units;
      }
    }
    var requiredCredits = 0;
    var electiveCredits = 0;
    if (totalUnits GT 0){
      if (reqNeeded GT 0 and totalUnits LTE reqNeeded ){
          requiredCredits = totalUnits;
      }else if (totalUnits GT reqNeeded){
        requiredCredits = reqNeeded;
      }
      if (eleNeeded GT 0 and totalUnits GT reqNeeded ){
          electiveCredits = totalUnits - reqNeeded;
      }

    }


    return {
    	totalTopics = arguments.topics.len(),
    	totalUnits = totalUnits,
      requiredCredits = requiredCredits,
      electiveCredits = electiveCredits
    };
  </cfscript>
  
  <cfcatch>
  	<cfscript>
		return {
			totalTopics = 0,
			totalUnits = 0,
      requiredCredits = 0,
      electiveCredits = 0

		};
	</cfscript>
  </cfcatch>
  </cftry>
</cffunction>
