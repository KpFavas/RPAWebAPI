*** Settings ***
Documentation    Account reconciliation using RPA
Library    OperatingSystem
Library     RequestsLibrary
Library     JSONLibrary
Library     Collections
Library     RPA.Excel.Files
Library     String
Library     DateTime
# Library     RPA.Browser.Selenium
*** Variables ***
${BaseUrl}      ${EMPTY}
${Username}     ${EMPTY}
${Username1}    ${EMPTY}
${Password}     ${EMPTY}
${From_Date}    ${EMPTY}
${To_Date}      ${EMPTY}
${BankAccountCode}      ${EMPTY}
${BankChargeAccountCode}    ${EMPTY}
@{Excel_transaction_details_list}    ${EMPTY}
${sessionname}      ${EMPTY} 
${headers}=  Create Dictionary  Content-Type=application/json

*** Tasks ***
Main Task
    Generate Unique Session Name
    Set Global Variables
    Converting Username
    Login Session Creation
    Json Validation
*** Keywords ***
Generate Unique Session Name
    ${timestamp}=       Get Current Date    result_format=%Y%m%d%H%M%S
    ${random_number}=   Generate Random String    6    0123456789
    ${sessionname}=     Set Variable    sapb1_${timestamp}_${random_number}
    Log To Console      ${sessionname}
Set Global Variables
    ${variables}=    Get File    variables.json
    # Log To Console      \nFileData: ${variables}
    ${variable_dict}=    Evaluate    json.loads('''${variables}''')
    Set Global Variable    ${BaseUrl}    ${variable_dict["BaseUrl"]}
    Set Global Variable    ${Username1}    ${variable_dict["Username"]}
    Set Global Variable    ${Password}    ${variable_dict["Password"]}
    Set Global Variable    ${From_Date}    ${variable_dict["From_Date"]}
    Set Global Variable    ${To_Date}    ${variable_dict["To_Date"]}
    Set Global Variable    ${BankAccountCode}    ${variable_dict["BankAccountCode"]}
    Set Global Variable    ${BankChargeAccountCode}    ${variable_dict["BankChargeAccountCode"]}
    Set Global Variable    ${Excel_transaction_details_list}    ${variable_dict["ExcelData"]}
Converting Username
    ${Username1}    Evaluate    "${Username1}".replace("'", '"')
    Set Global Variable    ${Username}      ${Username1}
Login Session Creation
    ${auth_data}=    Create List    ${Username}    ${Password}
    Create Session    ${sessionname}    ${base_url}/Login    auth=${auth_data}
    Log To Console      \nLogin Success
Json Validation
    Log To Console      \nExcel Data: ${Excel_transaction_details_list}
    Log To Console      Account Code: ${BankAccountCode}
    #Excel Length-------------------------------------
    ${Excel_Length}     Evaluate    len(${Excel_transaction_details_list})
    Log To Console      \nExcel Row Lenth : ${Excel_Length}
    #-------------------------------------------------
    
    # getting banktransaction details
    ${customer_response}    Get Request    ${sessionname}    ${BaseUrl}/JournalEntries?$filter=DueDate ge '${From_Date}' and DueDate le '${To_Date}'
    IF    ${customer_response.status_code} == 200
        ${Journal_filter_data}    Set Variable    ${customer_response.json()}
        ${JE_LineIDsList}    Create List
        ${account_codes}    Create List
        ${JE_CreditsList}  Create List
        ${JE_DebitsList}   Create List
        ${amounts}  Create List
        ${Trans_Ids}        Create List
        ${JE_DueDatesList}        Create List
        ${sorted_dict}      Create Dictionary
        ${filtered_data}    Create Dictionary
        FOR    ${entry}    IN    @{Journal_filter_data['value']}
            FOR    ${journal_line}    IN    @{entry['JournalEntryLines']}
                FOR    ${key}    ${value}    IN    &{journal_line}
                    Set To Dictionary    ${sorted_dict}    ${key}    ${value}
                END
                ${account_code}    Get From Dictionary    ${sorted_dict}    AccountCode
                IF    '${account_code}' == '${BankAccountCode}'
                    ${Trans_Id}     Set Variable    ${entry['JdtNum']}
                    ${JLine_Date}   Set Variable    ${journal_line['DueDate']}
                    FOR    ${key}    ${value}    IN    &{journal_line}
                        Set To Dictionary    ${filtered_data}    ${key}    ${value}
                    END
                    # Log To Console          \nFiltered journal Lines::::${filtered_data}
                    ${line_id}  Get From Dictionary    ${filtered_data}    Line_ID
                    ${credit}    Get From Dictionary    ${filtered_data}    Debit
                    ${credit}=    Convert To Number    ${credit}
                    ${credit}    Evaluate    "{:.2f}".format(${credit})
                    ${debit}   Get From Dictionary    ${filtered_data}    Credit
                    ${debit}=    Convert To Number    ${debit}
                    ${debit}    Evaluate    "{:.2f}".format(${debit})
                        Append To List    ${Trans_Ids}    ${Trans_Id}
                        Append To List    ${JE_DueDatesList}    ${JLine_Date}
                        Append To List    ${JE_LineIDsList}    ${line_id}
                        Append To List    ${JE_DebitsList}    ${debit}
                        Append To List    ${JE_CreditsList}    ${credit}
                END
            END
        END
        ${Dic_length}   Evaluate    len(@{JE_LineIDsList})
        Log To Console      \nTransIds : ${Trans_Ids}
        Log To Console      \nJL Date : ${JE_DueDatesList}
        Log To Console      \nLineIdsIds : ${JE_LineIDsList}
        Log To Console      \nJE_DebitsList : ${JE_DebitsList}
        Log To Console      \nJE_CreditsList : ${JE_CreditsList}
        Log To Console      \nGet Journal Entry - Succes...
    ELSE
        Log To Console      \nGet Journal Entry - Failed...
    END
    Log To Console      \n LengthFinal: ${Dic_length}
    ${journal_transaction_details_list}    Create List
    FOR    ${index}    IN RANGE    ${Dic_length}
        ${trans_id_tr}    Set Variable    ${Trans_Ids[${index}]}
        ${jlinesdate_tr}    Set Variable    ${JE_DueDatesList[${index}]}
        ${line_id_tr}    Set Variable    ${JE_LineIDsList[${index}]}
        ${credit_tr}    Set Variable    ${JE_CreditsList[${index}]}
        ${debit_tr}    Set Variable    ${JE_DebitsList[${index}]}
        ${transaction_details}    Create Dictionary
        Set To Dictionary    ${transaction_details}    TransID    ${trans_id_tr}
        Set To Dictionary    ${transaction_details}    jrLineDates    ${jlinesdate_tr}
        Set To Dictionary    ${transaction_details}    LineID    ${line_id_tr}
        Set To Dictionary    ${transaction_details}    Credit    ${credit_tr}
        Set To Dictionary    ${transaction_details}    Debit    ${debit_tr}
        Append To List    ${journal_transaction_details_list}    ${transaction_details}
    END
    Log To Console      \nFinal JE list: ${journal_transaction_details_list}
    ${JE_Length}    Evaluate    len(${journal_transaction_details_list})
    Log To Console       \nJE Length: ${JE_Length}    
    ${unmatched_records}    Create List
    ${matching_records}    Create List
    FOR    ${excel_record}    IN    @{Excel_transaction_details_list}
        ${excel_credit}     Set Variable    ${excel_record}[CreditAmount]
        IF    '${excel_credit}' != '' and '${excel_credit}'.isdecimal()
            ${excel_credit}     Convert To Number    ${excel_credit}
            ${excel_credit}     Evaluate    "{:.2f}".format(${excel_credit})
        ELSE
            Log To Console      \nError ${excel_credit}
        END
        ${excel_debit}      Set Variable    ${excel_record}[DebitAmount]
        IF    '${excel_debit}' != '' and '${excel_debit}'.isdecimal()
            ${excel_debit}     Convert To Number    ${excel_debit}
            ${excel_debit}     Evaluate    "{:.2f}".format(${excel_debit})
        ELSE
            Log To Console      \nError ${excel_debit}
        END
        ${excel_debi}       Convert To Number    ${excel_debit}
        ${excel_debit}      Evaluate    "{:.2f}".format(${excel_debit})
        ${excel_date1}      Set Variable    ${excel_record}[DueDate]
        ${excel_date}       Convert Date    ${excel_date1}    date_format=%Y%m%d    result_format=%Y-%m-%dT%H:%M:%SZ
        Log To Console      Date: ${excel_date}
        ${excel_details}    Set Variable    ${excel_record}[Memo]
        ${excel_reference}      Set Variable    ${excel_record}[Reference]
        ${is_matched}    Set Variable    ${False}
        FOR    ${journal_record}    IN    @{journal_transaction_details_list}
            ${journal_credit}    Set Variable    ${journal_record}[Credit]
            ${journal_credit}=    Convert To Number    ${journal_credit}
            ${journal_credit}    Evaluate    "{:.2f}".format(${journal_credit})
            ${journal_debit}    Set Variable    ${journal_record}[Debit]
            ${journal_debit}=    Convert To Number    ${journal_debit}
            ${journal_debit}    Evaluate    "{:.2f}".format(${journal_debit})
            ${journal_LineId}    Set Variable    ${journal_record}[LineID]
            ${journal_date}    Set Variable    ${journal_record}[jrLineDates]
            Log To Console      \nCheck:'${excel_credit}' == '${journal_credit}' and '${excel_credit}' != '0.00' and '${excel_date}' == '${journal_date}' 
            IF    '${excel_credit}' == '${journal_credit}' and '${excel_credit}' != '0.00' and '${excel_date}' == '${journal_date}'
                ${is_matched}    Set Variable    ${True}
                ${matching_record}    Set Variable    ${journal_record}
                ${trans_id}    Set Variable    ${matching_record}[TransID]
                ${matching_dict}    Create Dictionary    TransID=${trans_id}    Debit=${excel_debit}    Credit=${excel_credit}    Details=${excel_details}    Date=${excel_date}    Reference=${excel_reference}    Line_ID=${journal_LineId}
                Append To List    ${matching_records}    ${matching_dict}
                Exit For Loop       #To Exit the loop
            END
        END
        IF    not ${is_matched}
            Append To List    ${unmatched_records}    ${excel_record}
        END
    END
    Log To Console      \nUnMatched::::::: ${unmatched_records}
    Log To Console      \nMatched::::::: ${matching_records}
    ${lenMatched}   Evaluate    len(${matching_records})
    Log To Console    \nMatching Records: ${matching_records}       #Matchig record List
    Log To Console    Matching Records Lenghth: ${lenMatched}
    ${lenUnMatched}   Evaluate    len(${unmatched_records})
    Log To Console      \nNew Unmatched Record: ${unmatched_records}      #Unmatched recrod List
    ${New_Unmatched_Len}   Evaluate    len(${unmatched_records})
    Log To Console    \nUnMatching Records: ${New_Unmatched_Len}

    #####--- POST to Get The Reconciliation List --- #####
    ${matched_Ids_Un_rec}  Create List
    ${RecNumberlist}  Create List
    ${get_reconciled_data}      Create Dictionary
    IF      ${lenMatched} > 0
        ${recon_post}    Set Variable         {"ExternalReconciliationFilterParams": {"AccountCodeFrom": "${BankAccountCode}","AccountCodeTo": "${BankAccountCode}","ReconciliationAccountType": "rat_GLAccount"}}
        # ${reconcile_get_response}    Post Request   ${sessionname}    ${BaseUrl}/ExternalReconciliationsService_GetReconciliationList  data=${recon_post}  headers=${headers}
        ${reconcile_get_response}    Post Request    ${sessionname}    ${BaseUrl}/ExternalReconciliationsService_GetReconciliationList      data=${recon_post}
        IF    ${reconcile_get_response.status_code} == 200
            ${reconListdata}    Set Variable    ${reconcile_get_response.json()}
            ${recListValueSet}  Set Variable    ${reconListdata['value']}
            FOR    ${rec}    IN    @{reconListdata['value']}
                FOR    ${key}    ${value}    IN    &{rec}
                    Set To Dictionary    ${get_reconciled_data}    ${key}    ${value}
                END
                ${get_rec_data}     Get Dictionary Items        ${get_reconciled_data}
                ${recno}  Get From Dictionary    ${get_reconciled_data}    ReconciliationNo
                Append To List    ${RecNumberlist}    ${recno} 
            END
            Log To Console      \nGet Reconciled Data-Success...
            Log To Console      RecNumberlist:${RecNumberlist}          #Recon List 
        ELSE
            Log To Console      \nGet Reconciled Data- Failed...
            Log To Console      \n JSON: ${reconcile_get_response.json()}
        END
        
        #####--- POST to Get The Reconciliation Each complete data for compare IF Reconcieled Or Not  --- #####
        ${jdtNums_rec_List}     Create List
        FOR     ${recNum}   IN  @{RecNumberlist}
            ${rec_data_body}    Set Variable    {"ExternalReconciliationParams": {"AccountCode": "${BankAccountCode}","ReconciliationNo": ${recNum}}} 
            ${rec_data_body_get_response}    Post Request   ${sessionname}    ${BaseUrl}/ExternalReconciliationsService_GetReconciliation     data=${rec_data_body}
            IF    ${rec_data_body_get_response.status_code} == 200
                ${single_rec_json}      Set Variable    ${rec_data_body_get_response.json()}
                ${rec_jentry_lines}     Set Variable    ${single_rec_json['ReconciliationJournalEntryLines']}
                FOR     ${singleTrans}  IN  @{rec_jentry_lines}
                    ${jdtNums_rec}      Set Variable    ${singleTrans['TransactionNumber']}
                    Append To List   ${jdtNums_rec_List}      ${jdtNums_rec} 
                END
                FOR     ${arry1}    IN      @{Trans_Ids}
                    FOR     ${arry2}    IN      @{jdtNums_rec_List}
                        IF  '${arry1}' == '${arry2}'
                            Log To Console  '${arry1}' == '${arry2}'
                            Remove Values From List    ${Trans_Ids}    ${arry1}
                        END 
                    END
                END
                Log To Console  Reconciled JDTNUMs\t\t: ${jdtNums_rec_List}
            ELSE
                Log To Console      \nFailed Each Record get
            END
        END
    ELSE
        Log To Console      \n There were no records found with the given transaction details....
    END
    FOR    ${id}    IN    @{Trans_Ids}
        Append To List    ${matched_Ids_Un_rec}    ${id}
    END
    Log To Console  UnReconciled transIdss\t\t: ${matched_Ids_Un_rec}
    ${unRec_TransIdlenth}     Evaluate    len(${matched_Ids_Un_rec})
    Log To Console  \nUnReconciledTransId Lenth\t: ${unRec_TransIdlenth}
    IF      ${unRec_TransIdlenth}>0
        ${TransIDsMatchedList}     Create List
        ${LineIdsMatchedList}     Create List
        ${CreditMatchedList}     Create List
        ${DebitMatchedList}     Create List
        ${DetailsMatchedList}     Create List
        ${DatesMatchedList}     Create List
        ${referenceMatchedList}     Create List

        ################# Matched
        #===========================TransID

        FOR     ${TransIdMatched}    IN      @{matching_records} 
            ${transideach}     Set Variable    ${TransIdMatched['TransID']}
            Append To List      ${TransIDsMatchedList}     ${transideach}
        END
        #===========================LineId

        FOR     ${LineIdMatched}    IN      @{matching_records} 
            ${lineideach}     Set Variable    ${LineIdMatched['Line_ID']}
            Append To List      ${LineIdsMatchedList}     ${lineideach}
        END

        #===========================Credits

        FOR     ${creditsMatched}    IN      @{matching_records} 
            ${Credr}     Set Variable    ${creditsMatched['Credit']}
            Append To List      ${CreditMatchedList}     ${Credr}
        END

        #===========================Debits

        FOR     ${DebitsMatched}    IN      @{matching_records} 
            ${matchdr}     Set Variable    ${DebitsMatched['Debit']}
            Append To List      ${DebitMatchedList}     ${matchdr}
        END

        #===========================Details

        FOR     ${detailsMatched}    IN      @{matching_records} 
            ${detai}     Set Variable    ${detailsMatched['Details']}
            Append To List      ${DetailsMatchedList}     ${detai}
        END

        #===========================Dates

        FOR     ${datesMatched}    IN      @{matching_records} 
            ${datee}     Set Variable    ${datesMatched['Date']}
            Append To List      ${DatesMatchedList}     ${datee}
        END

        #===========================RefNos

        FOR     ${RefsMatched}    IN      @{matching_records} 
            ${reff}     Set Variable    ${RefsMatched['Reference']}
            Append To List      ${referenceMatchedList}     ${reff}
        END

        #===========================
        #^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
        ${Credits_UnMatchedList}     Create List
        ${Debits_UnMatchedList}     Create List
        ${Details_UnMatchedList}     Create List
        ${Dates_UnMatchedList}     Create List
        ${reference_UnMatchedList}     Create List
        ################# UnMatched   

        #===========================Credits

        FOR     ${CreditsunMatched}    IN      @{unmatched_records} 
            ${credun}     Set Variable    ${CreditsunMatched['CreditAmount']}
            Append To List      ${Credits_UnMatchedList}     ${credun}
        END

        #===========================Debits

        FOR     ${DebitstsUnMatched}    IN      @{unmatched_records} 
            ${debr}     Set Variable    ${DebitstsUnMatched['DebitAmount']}
            Append To List      ${Debits_UnMatchedList}     ${debr}
        END    

        #===========================Details

        FOR     ${DetailsUnMatched}    IN      @{unmatched_records} 
            ${detailsun}     Set Variable    ${DetailsUnMatched['Memo']}
            Append To List      ${Details_UnMatchedList}     ${detailsun}
        END

        #===========================Dates

        FOR     ${DatesUnMatched}    IN      @{unmatched_records} 
            ${dateun}     Set Variable    ${DatesUnMatched['DueDate']}
            Append To List      ${Dates_UnMatchedList}      ${dateun}
        END

        #===========================RefNos

        FOR     ${RefsUnMatched}    IN      @{unmatched_records} 
            ${refun}     Set Variable    ${RefsUnMatched['Reference']}
            Append To List      ${reference_UnMatchedList}     ${refun}
        END


        Log To Console      \nMatched records
        Log To Console      Final Matched UnRec Trans_IdList\t:${TransIDsMatchedList}
        ${Matched_UnRec_TransIds_Length}    Evaluate    len(${TransIDsMatchedList})
        Log To Console      \nMatched records
        Log To Console      Final Matched UnRec LineIdList\t:${LineIdsMatchedList}
        Log To Console      Final Matched UnRec CreditsList\t:${CreditMatchedList}
        Log To Console      Final Matched UnRec DebitsList\t:${DebitMatchedList}
        Log To Console      Final Matched UnRec DetailsList\t:${DetailsMatchedList}
        Log To Console      Final Matched UnRec DatesList\t:${DatesMatchedList}
        Log To Console      Final Matched UnRec referenceList\t:${referenceMatchedList}

        Log To Console      \nUnmatched records 
        Log To Console      DetailsList\t:${Details_UnMatchedList}
        Log To Console      DatesList\t:${Dates_UnMatchedList}
        Log To Console      referenceList\t:${reference_UnMatchedList}
        Log To Console      CreditList\t:${Credits_UnMatchedList}
        Log To Console      DebitsList\t:${Debits_UnMatchedList}
        # ${DebitSum}     Evaluate    sum(${Debits_UnMatchedList})
        ${DebitSum}    Set Variable    0
        FOR    ${s}    IN    @{Debits_UnMatchedList}
            ${s}    Convert To Number    ${s}
            ${s}    Evaluate    "{:.2f}".format(${s})
            ${DebitSum}    Evaluate    ${DebitSum} + ${s}
        END
        Log To Console      \nSum::::::::::${DebitSum} 
    END
    ###############----------BankPage POST----------###############
    ${sequencelist}     Create List
    Log To Console      \nChecking:::::::::TransIDLEngthMatchedCount:${Matched_UnRec_TransIds_Length}
    # Log To Console      \nChecking:::::::::TransIDLEngthMatched:${unRec_TransIdlenth}
    Log To Console      \nChecking:::::::::New UnMatchedLEngth:${New_Unmatched_Len}
    ${total_recs_toReconcile}       Set Variable        ${Matched_UnRec_TransIds_Length+${New_Unmatched_Len}}
    Log To Console      \nTotal Records To Reconcile: ${total_recs_toReconcile}
    IF  ${total_recs_toReconcile}>0
        FOR     ${counter}  IN RANGE    0   ${total_recs_toReconcile}
            IF      ${Matched_UnRec_TransIds_Length}>0
                IF  ${counter} < ${Matched_UnRec_TransIds_Length}
                    IF    '${DebitMatchedList}[${counter}]' == '0.00'
                        ${Ref_No}    Set Variable    ${referenceMatchedList}[${counter}]
                        IF      '${Ref_No}' == '0'
                            ${Ref_No}   Set Variable    null
                        ELSE
                            ${Ref_No}   Set Variable    ${Ref_No}
                        END
                        ${payload1}     Set variable        {"AccountCode": "${BankAccountCode}", "CreditAmount": "${CreditMatchedList}[${counter}]", "DocNumberType": "bpdt_DocNum", "Reference": ${Ref_No},"Memo":"${DetailsMatchedList}[${counter}]","DueDate":"${DatesMatchedList}[${counter}]"} 
                        Log To Console      Bank Page Post Body1:${payload1}
                        # ${response}=  Post Request  ${sessionname}    ${BaseUrl}/BankPages  data=${payload1}
                        # IF    ${response.status_code} == 201
                        #     ${bankpage_response}    Set Variable    ${response.json()}
                        #     ${seqno}    Set Variable    ${bankpage_response['Sequence']}
                        #     Append To List    ${sequencelist}    ${seqno}
                        #     Log To Console    \nPOST BankPages:::::::::: - Success...
                        # ELSE
                        #     Log To Console    \nPOST BankPages:::::::::: - Failed...
                        # END
                    END
                END
            END
            IF  ${New_Unmatched_Len}>0
                IF  ${counter} < ${New_Unmatched_Len}
                    IF    '${Credits_UnMatchedList}[${counter}]' == '0.00'
                        ${Ref_No}    Set Variable    ${reference_UnMatchedList}[${counter}]
                        IF      '${Ref_No}' == '0'
                            ${Ref_No}   Set Variable    null
                        ELSE
                            ${Ref_No}   Set Variable    ${Ref_No}
                        END
                        ${payload1}     Set variable        {"AccountCode": "${BankAccountCode}", "DebitAmount": "${Debits_UnMatchedList}[${counter}]", "DocNumberType": "bpdt_DocNum", "Reference": ${Ref_No},"Memo":"${Details_UnMatchedList}[${counter}]","DueDate":"${Dates_UnMatchedList}[${counter}]"} 
                        Log To Console      Bank Page Post Body1:${payload1}
                        # ${response}=  Post Request  ${sessionname}    ${BaseUrl}/BankPages  data=${payload1}
                        # IF    ${response.status_code} == 201
                        #     ${bankpage_response}    Set Variable    ${response.json()}
                        #     ${seqno}    Set Variable    ${bankpage_response['Sequence']}
                        #     Append To List    ${sequencelist}    ${seqno}
                        #     Log To Console    \nPOST BankPages:::::::::: - Success...
                        # ELSE
                        #     Log To Console    \nPOST BankPages:::::::::: - Failed...
                        # END
                    END
                END
            END
        END
    ELSE
        Log To Console      \nNothing To reconsile.......
    END
    Log To Console      \nSequence List From BankPage : ${sequencelist}
    ${bnk_page_seq_lenth}   Evaluate    len(${sequencelist})
    Log To Console      \nSequence List From BankPage Length : ${bnk_page_seq_lenth}
    Log To Console      \nUnMatched Length: ${New_Unmatched_Len}
    
    ##############----------POST & GET Journal Entry Lines----------###############
    # ${JdtNumbsList}     Create List
    # # ${JlinesTransNumbersList}     Create List
    # ${JlinesList}     Create List
    # IF      ${New_Unmatched_Len} > 0
    #     ${PAYLOAD2}    Set Variable         {"JournalEntryLines": [{"AccountCode": "${rev_bank}","Credit": ${DebitSum},"Debit": 0.0,"BPLID": 1},{"AccountCode": "${bank_charge_paid}","Credit": 0.0,"Debit": ${DebitSum},"BPLID": 1}]}
    #     Log To Console      \nPOST PayloadJlines: ${PAYLOAD2}
    #     ${responseJEntry}=  Post Request  ${sessionname}    ${base_url}/JournalEntries  data=${PAYLOAD2}  headers=${headers}
    #     IF    ${responseJEntry.status_code} == 201
    #         ${JEntrypostResponseBody}       Set Variable        ${responseJEntry.json()}
    #         ${JdtNumberss}       Set Variable        ${JEntrypostResponseBody['JdtNum']}
    #         ${Jlines}       Set Variable        ${JEntrypostResponseBody['JournalEntryLines']}
    #         Append To List      ${JlinesList}     ${Jlines}
    #         Append To List      ${JdtNumbsList}     ${JdtNumberss}
    #         Log To Console    \nSuccessjournalentry
    #     ELSE
    #         Log To Console    \nFailjournalentry ${responseJEntry.json()}
    #     END
    # END

    # # Log To Console     \nGetting JlinesList :::::::: ${JlinesList} 
    # Log To Console     \nGetting tans_Idddddd :::::::: ${JdtNumbsList} 
    
    # ${JdtNumbsListLength}       Evaluate        len(${JdtNumbsList})
    # Log To Console      \nnPostJentryLengthIds:${JdtNumbsListLength}

    # ${mixed_JdtNum_list}    Create List    @{JdtNumbsList}    @{matched_Ids_Un_rec}
    # ${mixed_JdtNum_list_Length}     Evaluate    len(${mixed_JdtNum_list})
    # log To Console      \nMixedID List::${mixed_JdtNum_list}
    # log To Console      \nMixedID List Length::${mixed_JdtNum_list_Length}

