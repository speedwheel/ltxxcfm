<!---
Also this is the url for Maryland API: https://ltxx.bunity.com/v1/md
Header: Authorization Basic a2F6ZWxpOj5zWzVaN11bRU4rayk7U2s=
Body: you need to send 3 fields: reg_number, password, license_type (can be either: broker, associate_broker, salesperson)


Fernando	Barrueta	643461	fernando.barrueta@colliers.com	Molly1430

https://www.dllr.state.md.us/cgi-bin/ElectronicLicensing/RE/CE/CEquery1.cgi

--->


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
<cftry>






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

		where lc.fk_stateID = 21 <!---this is the state ID--->
		
		<cfif previewSearch neq ""><!---this is added so that a specific license can be scraped--->
			and t.pk_trackerSearchID = <cfqueryparam value="#previewSearch#">
		<cfelse>
			<!---here we only collect licenses that have the information required to login and collect the information--->
			and t.LicensePassword != '' and t.LicensePassword is not Null
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

		where lc.fk_stateID = 21 <!---this is the state ID--->
		
		<cfif preview neq ""><!---this is added so that a specific license can be scraped--->
			and t.pk_trackerID = <cfqueryparam value="#preview#">
		<cfelse>
			<!---here we only collect licenses that have the information required to login and collect the information--->
			and t.LicensePassword != '' and t.LicensePassword is not Null
			and t.trackerLicenseid != '' and t.trackerLicenseid is not Null
			order by newid()
		</cfif>
	</cfquery>
</cfif>

<cfif getRecord.recordcount eq 0>
	No license found
</cfif>



<table style="font-family: Gotham, 'Helvetica Neue', Helvetica, Arial, 'sans-serif'" cellspacing="1" cellpadding="8" bgcolor="white">
	<tr>
		<td colspan="10" style="padding: 0">
			<table width="100%" border="0" cellspacing="0" cellpadding="0">
			  <tr> 
				   <td width="8"><img src="#event.getModuleRoot()#/includes/img/box_red_left.gif" width="8" height="39"></td>
					  <td bgcolor="efdfdf" class="TitleMainBoxText">&nbsp;<strong>Maryland Test Scraper</strong></td>
					   <td width="8"><img src="#event.getModuleRoot()#/includes/img/box_red_right.gif" width="8" height="39"></td>
				   </tr>
			</table>
		</td>
	</tr>
	
	<cfloop query="getRecord">
		<tr class="lightBlueBG2">
			<td class="sbWhite">#getRecord.firstname# #getRecord.lastname#</td><!---name as found in the kazeli DB--->
			<td class="sbWhite">#getRecord.l_dispname#</td><!---licence name as found in the kazeli DB--->
			<td class="sbWhite">#getRecord.trackerLicenseid# (#dateformat(getRecord.renewalDate,'mm/dd/yyyy')#)</td><!---login licensceID and renual date as found in the kazeli DB--->
			<td class="sbWhite">#getRecord.LicenseEmail#</td><!---login email as found in the kazeli DB--->
			<td class="sbWhite">#getRecord.LicensePassword#</td><!---password email as found in the kazeli DB--->
			<td class="sbWhite">#getRecord.requiredParam#</td><!---parameters used to differentciate required credits--->
			<td class="sbWhite">#getRecord.electiveParam#</td><!---parameters used to differentciate elective credits--->
			<td class="sbWhite">Kazeli</td>
		</tr>
		
		
		<cftry>
			<!---These parameters/url will be defined by Edward for each state so these will vary--->
			<cfhttp method="POST" url="https://ltxx.bunity.com/v1/md" result="resultText">
				<cfhttpparam type="header" name="Authorization" value="Basic a2F6ZWxpOj5zWzVaN11bRU4rayk7U2s=" />
				<cfhttpparam name="reg_number" type="formfield" value="#getRecord.trackerLicenseid#">
				<cfhttpparam name="password" type="formfield" value="#getRecord.LicensePassword#">
				<cfhttpparam name="license_type" type="formfield" value="#getRecord.apiType#">
			</cfhttp>
			<cfset json = DeserializeJSON(resultText.Filecontent)>
			
			<cfif isdefined('json.error')>
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
				<cfset reqCol = 0><!---var to collect required credits--->
				<cfset electCol = 0><!---var to collect elective credits--->
				<cfset requiredParam = getRecord.requiredParam><!---parameters used to differentciate required credits--->
				<cfset electiveParam = getRecord.electiveParam><!---parameters used to differentciate elective credits--->


				<cfset scrp_name = json.name><!---users name as returned by scrape--->
				<cfset scrp_type = json.license.type><!---license type as returned by scrape--->
				<cfset scrp_expiration_date = json.license.expiration_date><!---expiration date as returned by scrape---> 
				<cfif isDefined('json.topics')>
					<cfset scrp_topics = json.topics><!---topics taken as returned by scrape---> 
				<cfelse>
					<cfset scrp_topics = "">
				</cfif>


				<cfset r = ArrayNew(1)><!---array to hold required credits--->
				<cfset e = ArrayNew(1)><!---array to hold elective credits--->

				<cfif IsArray(scrp_topics)>
					
					<cfloop from="1" to="#arraylen(scrp_topics)#" index="idx">
						<cfset OK = 1>
						<cfset scrpError = "">
						<cftry>
							<cfset testVar = scrp_topics[idx].name>
							<cfif testVar eq "">
								<cfset OK = 0>
							<cfelseif findnocase('error',testVar)>
								<cfset OK = 0>
								<cfset scrpError = testVar>
								<cfbreak>
							</cfif>
							<cfcatch><cfset OK = 0></cfcatch>
						</cftry>
						
						<cfif OK eq 1>
							<cfset name = scrp_topics[idx].name><!---topic name--->
							<cfset hours_reported = scrp_topics[idx].hours_reported><!---credits found for specific topic--->
							<cfset t = left(name,1)><!---get first letter of topic name to be used as reference for requiredParam and electiveParam--->
							<cfset addr = 0><!---mark as not used to reset value--->
							<cfset adde = 0><!---mark as not used to reset value--->

							<cfif requiredParam neq ""><!---if template has required parameters--->
								<cfif listFindnocase(requiredParam,t)><!---if found in required parameters add to required credits --->
									<cfset addr = 1><!---flag to add as require credit--->
									<cfset adde = 0><!---flag not to add as elective credit--->
									<cfif arraylen(r) gt 0><!---check to see if topic is found twice--->
										<cfloop from="1" to="#arraylen(r)#" index="idxr">
											<cfif r[idxr] eq name><!---if topic found in required credit array add credits to electives--->
												<cfset addr = 0><!---flag not to add as require credit--->
												<cfset adde = 1><!---flag to add as elective credit--->
											</cfif>
										</cfloop>
									</cfif>

									<cfif addr eq 1><!---add to required credits--->
										<cfset temp = ArrayAppend(r,name)>
										<cfset reqCol = reqCol + hours_reported>
									</cfif>
									<cfif adde eq 1><!---add to elective credits--->
										<cfset temp = ArrayAppend(e,name)>
										<cfset electCol = electCol + hours_reported>
									</cfif>
								</cfif>
							</cfif>

							<cfif electiveParam neq ""><!---if template has elective  parameters--->
								<cfif listFindnocase(electiveParam,t)><!---if found in elective parameters add to elective credits --->
									<cfset adde = 1><!---flag to add as elective credit--->
									<cfif arraylen(e) gt 0><!---check to see if topic is found twice--->
										<cfloop from="1" to="#arraylen(e)#" index="idxe">
											<cftry>
                                                <cfif r[idxe] eq name><!---if topic found in elective credit array dont add to electives--->
                                                    <cfset adde = 0><!---flag not to add as elective credit--->
                                                </cfif>
                                                <cfcatch></cfcatch>
                                            </cftry>
										</cfloop>
									</cfif>

									<cfif adde eq 1><!---add to elective credits--->
										<cfset temp = ArrayAppend(e,name)>
										<cfset electCol = electCol + hours_reported>
									</cfif>
								</cfif>
							</cfif>

							<cfif adde eq 0 and addr eq 0><!---if topic not found in elctive or required params add to elective credits--->
								<cfset temp = ArrayAppend(e,name)>
								<cfset electCol = electCol + hours_reported>
							</cfif>
						</cfif>

					</cfloop>

				</cfif>

				<cfif reqCol gt req><!---If the collected required credits are more than the template requires set the same as the state required value--->
					<cfset reqCol = req>
				</cfif>
				<cfif electCol gt elect><!---If the collected elective credits are more than the template requires set the same as the state elective value--->
					<cfset electCol = elect>
				</cfif>
			
			
				<tr bgcolor="EAEAEA">
					<td>#scrp_name#</td>
					<td>#scrp_type#</td>
					<td>Exp: #dateformat(left(scrp_expiration_date,10),'mm/dd/yyyy')#</td>
					<td colspan="2">&nbsp;</td>
					<td><strong>Req:</strong> #reqCol# of #req#</td>
					<td><strong>Elect:</strong> #electCol# of #elect#</td>
					<td>Scrape</td>
				</tr>
				<tr bgcolor="white">
					<td colspan="10">

						<cfif IsArray(scrp_topics) and ArrayLen(scrp_topics) gte 1>
							<table border="1" class="sblack" cellspacing="0">
							<cfloop from="1" to="#arraylen(scrp_topics)#" index="idx">
								<cfset OK = 1>
								<cftry>
									<cfset testVar = scrp_topics[idx].hours_reported>
									<cfcatch><cfset OK = 0></cfcatch>
								</cftry>

								<cfif OK eq 1>
									<tr>
										<td>#scrp_topics[idx].name#</td>
										<td>#scrp_topics[idx].course_id#</td>
										<td>#scrp_topics[idx].hours_reported#</td>
										<td>#scrp_topics[idx].course_completion_date#</td>
										<td>#scrp_topics[idx].provider#</td>
									</tr>
								</cfif>
							</cfloop>
							</table>
						<cfelse>
							No topics found
						</cfif>
						<cfif isdefined('scrpError') and scrpError neq "">
							Error: #scrpError#
						</cfif>

					</td>
				</tr>
				
				<!---store values in the db --->
				<cfparam name="scrpError" default="">
				<cfif scrpError eq "">
					<cfif previewSearch neq "">
						<cfquery name="addData">
							update kirks_trackerSearch set
								scrp_rCredits = <cfqueryparam value="#reqCol#">,
								scrp_eCredits = <cfqueryparam value="#electCol#">, 
								scrp_date = #createODBCdatetime(now())#,
								scrp_success_date = #createODBCdatetime(now())#,
								scrp_topics = <cfqueryparam value="#SerializeJSON(scrp_topics)#">,
								scrp_result = <cfqueryparam value="1">,<!---flagged as a good scrape--->
								scrp_error = <cfqueryparam value="">,
								<cfif scrp_expiration_date eq "">
									scrp_expire = <cfqueryparam cfsqltype="CF_SQL_DATE" null="Yes"> 
								<cfelse>
									scrp_expire = #createODBCdate(dateformat(left(scrp_expiration_date,10),'mm/dd/yyyy'))#
								</cfif>
							where pk_trackerSearchID = <cfqueryparam value="#getRecord.pk_trackerSearchID#">
						</cfquery>
					<cfelse>
						<cfquery name="addData">
							update kirks_tracker set
								scrp_rCredits = <cfqueryparam value="#reqCol#">,
								scrp_eCredits = <cfqueryparam value="#electCol#">, 
								scrp_date = #createODBCdatetime(now())#,
								scrp_success_date = #createODBCdatetime(now())#,
								scrp_topics = <cfqueryparam value="#SerializeJSON(scrp_topics)#">,
								scrp_result = <cfqueryparam value="1">,<!---flagged as a good scrape--->
								scrp_error = <cfqueryparam value="">,
								<cfif scrp_expiration_date eq "">
									scrp_expire = <cfqueryparam cfsqltype="CF_SQL_DATE" null="Yes"> 
								<cfelse>
									scrp_expire = #createODBCdate(dateformat(left(scrp_expiration_date,10),'mm/dd/yyyy'))#
								</cfif>
							where pk_trackerID = <cfqueryparam value="#getRecord.pk_trackerID#">
						</cfquery>
					</cfif>
						
				<cfelse>
					<cfif previewSearch neq "">
						<cfquery name="addData">
							update kirks_trackerSearch set
								scrp_date = #createODBCdatetime(now())#,
								scrp_result = <cfqueryparam value="-1">,
								scrp_error = <cfqueryparam value="#scrpError#">
							where pk_trackerSearchID = <cfqueryparam value="#getRecord.pk_trackerSearchID#">
						</cfquery>
					<cfelse>
						<cfquery name="addData">
							update kirks_tracker set
								scrp_date = #createODBCdatetime(now())#,
								scrp_result = <cfqueryparam value="-1">,
								scrp_error = <cfqueryparam value="#scrpError#">
							where pk_trackerID = <cfqueryparam value="#getRecord.pk_trackerID#">
						</cfquery>
					</cfif>
						
				
				</cfif>
					
				
			</cfif>
			
			
			
			<cfcatch>
				<tr style="background-color:palevioletred">
					<td colspan="10">Error Pulling Data<br><cfdump var="#cfcatch#"></td>
				</tr>
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