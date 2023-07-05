*** Settings ***
Documentation    account reconciliation using RPA 
Library     RequestsLibrary
Library     Collections
Library     RPA.Excel.Files
Library     String
Library     DateTime
Library     RPA.Browser.Selenium
Library     JSONLibrary
*** Variables ***
${base_url}    http://116.74.253.177:50001/b1s/v1
${username}    {"CompanyDB": "SBODemoIN","UserName": "favas"}
${password}    Test@123
${sessionname}    sapb
${url}          ${OUTPUT_DIR}${/}/OBNK-Sheet.xlsx
${datatype}    rat_GLAccount
${bank}    100000
${bank1}    450005
${success_msg}      Reconciliation Success
${fail_msg}      Reconciliation Failure
${fail_msg2}       Record Not Found
${rev_bank}      161012
${bank_charge_paid}      650010
${line_ID}      0
*** Tasks ***    
main task 
    main page
    ${excelinfo}    ${exceld}   ${From_Date}    ${To_Date}    first page
    second page    ${excelinfo}    ${exceld}    ${From_Date}    ${To_Date}

    
*** Keywords ***
main page
    ${auth_data}=    Create List    ${username}    ${password}
    Create Session    ${sessionname}    ${base_url}/Login    auth=${auth_data}
first page
    Open Workbook    ${url}
    Set Active Worksheet    Sheet1
    ${code}     Get Cell Value    1    2
    ${From_Date}     Get Cell Value    2    3
    ${From_Date}    Convert Date    ${From_Date}    result_format=%Y-%m-%dT%H:%M:%SZ
    ${To_Date}     Get Cell Value    3    3
    ${To_Date}    Convert Date    ${To_Date}    result_format=%Y-%m-%dT%H:%M:%SZ
    ${exceldata}=    Read Worksheet As Table    header=True    start=5    trim=${True}
    Save Workbook   
    [Return]    ${exceldata}    ${code}     ${From_Date}    ${To_Date}  
second page
    [Arguments]    ${exceld}    ${coded}     ${From_Date}    ${To_Date}
    ${linidlist}=    Create List
    ${Refnolist}=    Create List
    ${Excel_Debitlist}=    Create List
    ${Excel_Creditlist}=    Create List
    ${sequencelist}=    Create List
    ${TransIDlist}=    Create List
    ${Transdatelist}=    Create List
    ${Detailslist}=    Create List
    ${RecNumberlist}=    Create List
    ${get_reconciled_data}    Create Dictionary 
    ${headers}=  Create Dictionary  Content-Type=application/json
    ########---getting Excel data through loop---########
    FOR    ${data}    IN    @{exceld}
        ${Excel_TransID}    Set Variable    ${data}[Transaction ID]
        ${Excel_Debit}    Set Variable    ${data}[Debit]
        ${Excel_Credit}    Set Variable    ${data}[Credit]
        ${Excel_Details}    Set Variable    ${data}[Details]
        ${exTransID}    Set Variable    ${data}[Transaction ID]
        ${exTransID}    Run Keyword If    '${exTransID}' == 'None'    Set Variable    0    ELSE    Set Variable    ${exTransID}
        ${exTransdate}    Set Variable    ${data}[Transaction date]
        ${exTransdate}       Convert Date    ${exTransdate}    result_format=%Y-%m-%dT%H:%M:%SZ
        ${exRefno}    Set Variable    ${data}[Reference No.]
        ${exRefno}    Run Keyword If    '${exRefno}' == 'None'    Set Variable    0    ELSE    Set Variable    ${exRefno}
        ${exDetails}    Set Variable    ${data}[Details]
        ${exDetails}    Run Keyword If    '${exDetails}' == 'None'    Set Variable    0    ELSE    Set Variable    ${exDetails}
        ${exDebit}    Set Variable    ${data}[Debit]
        ${exDebit}    Run Keyword If    '${exDebit}' == 'None'    Set Variable    0    ELSE    Set Variable    ${exDebit}
        ${exCredit}    Set Variable    ${data}[Credit]
        ${exCredit}    Run Keyword If    '${exCredit}' == 'None'    Set Variable    0    ELSE    Set Variable    ${exCredit}
        Append To List    ${TransIDlist}    ${exTransID}
        Append To List    ${Transdatelist}    ${exTransdate}
        Append To List    ${Refnolist}    ${exRefno}
        Append To List    ${Excel_Debitlist}    ${exDebit}
        Append To List    ${Excel_Creditlist}    ${exCredit}
        Append To List    ${Detailslist}    ${exDetails}
    END
    Log To Console      \nTransID list From Excel : ${TransIDlist}
    Log To Console      Transdatelist Excel : ${Transdatelist}
    Log To Console      Excel_Debitlist : ${Excel_Debitlist}\n
    Log To Console      Excel_Creditlist : ${Excel_Creditlist}\n
    ${debitlist_without_zeros}    Create List
    FOR    ${debit}    IN    @{Excel_Debitlist}
        ${debit}  Convert To Number   ${debit}
        Run Keyword If    '${debit}' != '0.0'    Append To List    ${debitlist_without_zeros}    ${debit}
    END
    ${creditlist_without_zeros}    Create List
    FOR    ${credit}    IN    @{Excel_Creditlist}
        ${credit}  Convert To Number   ${credit}
        Run Keyword If    '${credit}' != '0.0'    Append To List    ${creditlist_without_zeros}    ${credit}
    END

    ${len_of_excel_credits}     Evaluate    len(${creditlist_without_zeros})
    ${len_of_excel_debits}     Evaluate    len(${debitlist_without_zeros})
    
    Log To Console    Excel_Debitlist without zeros: ${debitlist_without_zeros}
    Log To Console    Excel_Creditlist without zeros: ${creditlist_without_zeros}

    ${len_of_excel_debits}      Evaluate    len(${TransIDlist})
    Log To Console    Excel_TransIdsLength: ${len_of_excel_debits}

    ${Excel_transaction_details_list}   Create List
    FOR     ${idx}    IN RANGE    ${len_of_excel_debits}
        ${trans_exId}    Set Variable    ${TransIDlist[${idx}]}
        ${trans_exDate}    Set Variable    ${Transdatelist[${idx}]}
        ${trans_exRefNo}    Set Variable    ${Refnolist[${idx}]}
        ${trans_exDetails}    Set Variable    ${Detailslist[${idx}]}
        ${trans_exDr}    Set Variable    ${Excel_Debitlist[${idx}]}
        ${trans_exDr}  Convert To Number   ${trans_exDr}
        ${trans_exCr}    Set Variable    ${Excel_Creditlist[${idx}]}
        ${trans_exCr}  Convert To Number   ${trans_exCr}
        ${ExcelTransactionDetails}    Create Dictionary
        Set To Dictionary    ${ExcelTransactionDetails}    TransID    ${trans_exId}
        Set To Dictionary    ${ExcelTransactionDetails}    Date    ${trans_exDate}
        Set To Dictionary    ${ExcelTransactionDetails}    RefNo    ${trans_exRefNo}
        Set To Dictionary    ${ExcelTransactionDetails}    Details    ${trans_exDetails}
        Set To Dictionary    ${ExcelTransactionDetails}    Credit    ${trans_exCr}
        Set To Dictionary    ${ExcelTransactionDetails}    Debit    ${trans_exDr}
        Append To List    ${Excel_transaction_details_list}    ${ExcelTransactionDetails}
    END
    # Log To Console      \nAll Excel data List: ${Excel_transaction_details_list}




# ////////////////////////////////////////////////
    

    # getting banktransaction details
    ${customer_response}    Get Request    ${sessionname}    ${base_url}/JournalEntries?$filter=DueDate ge '${From_Date}' and DueDate le '${To_Date}'
    IF    ${customer_response.status_code} == 200
        ${Journal_filter_data}    Set Variable    ${customer_response.json()}
        ${line_ids}    Create List
        ${account_codes}    Create List
        ${credits}  Create List
        ${debits}   Create List
        ${amounts}  Create List
        ${Trans_Ids}        Create List
        ${JLine_DatesList}        Create List
        ${sorted_dict}      Create Dictionary 
        ${filtered_data}    Create Dictionary 
        FOR    ${entry}    IN    @{Journal_filter_data['value']}
            FOR    ${journal_line}    IN    @{entry['JournalEntryLines']}
                FOR    ${key}    ${value}    IN    &{journal_line}
                    Set To Dictionary    ${sorted_dict}    ${key}    ${value}
                END
                
                # ${sortedData}   	Get Dictionary Items	${sorted_dict}	
                
                ${account_code}    Get From Dictionary    ${sorted_dict}    AccountCode
                IF    '${account_code}' == '${rev_bank}'
                    ${Trans_Id}     Set Variable    ${entry['JdtNum']}
                    ${JLine_Date}   Set Variable    ${journal_line['DueDate']}
                    FOR    ${key}    ${value}    IN    &{journal_line}
                        Set To Dictionary    ${filtered_data}    ${key}    ${value}
                    END
                    ${line_id}  Get From Dictionary    ${filtered_data}    Line_ID
                    ${credit}    Get From Dictionary    ${filtered_data}    Debit
                    ${debit}   Get From Dictionary    ${filtered_data}    Credit
                    
                        Append To List    ${Trans_Ids}    ${Trans_Id}
                        Append To List    ${JLine_DatesList}    ${JLine_Date}
                        Append To List    ${line_ids}    ${line_id}
                        Append To List    ${debits}    ${debit}   
                        Append To List    ${credits}    ${credit}  
                END 
            END
        END
        ${Dic_length}   Evaluate    len(@{line_ids})
        Log To Console      \nGet Journal Entry - Succes...
    ELSE
        Log To Console      \nGet Journal Entry - Failed...
    END
    Log To Console      \n LengthFinal: ${Dic_length}
    
######################### ^^^^Journal Entry Filtered^^^^ ########################

    ${journal_transaction_details_list}    Create List
    FOR    ${index}    IN RANGE    ${Dic_length}
        ${trans_id_tr}    Set Variable    ${Trans_Ids[${index}]}
        ${jlinesdate_tr}    Set Variable    ${JLine_DatesList[${index}]}
        ${line_id_tr}    Set Variable    ${line_ids[${index}]}
        ${credit_tr}    Set Variable    ${credits[${index}]}
        ${debit_tr}    Set Variable    ${debits[${index}]}
        
        ${transaction_details}    Create Dictionary
        Set To Dictionary    ${transaction_details}    TransID    ${trans_id_tr}
        Set To Dictionary    ${transaction_details}    jrLineDates    ${jlinesdate_tr}
        Set To Dictionary    ${transaction_details}    LineID    ${line_id_tr}
        Set To Dictionary    ${transaction_details}    Credit    ${credit_tr}
        Set To Dictionary    ${transaction_details}    Debit    ${debit_tr}
        
        Append To List    ${journal_transaction_details_list}    ${transaction_details}
    END

    ###################### Transactions Are Matched/Not Mached########################

    Log To Console    \nJLinesTransaction Details List: ${journal_transaction_details_list}
    Log To Console    \nExcelTransaction Details List: ${Excel_transaction_details_list}

    ${matching_records}    Create List
    ${unmatched_records}    Create List
    FOR    ${excel_record}    IN    @{Excel_transaction_details_list}
        ${excel_credit}    Set Variable    ${excel_record}[Credit]
        ${excel_debit}    Set Variable    ${excel_record}[Debit]
        ${excel_date}    Set Variable    ${excel_record}[Date]
        ${excel_details}    Set Variable    ${excel_record}[Details]
        ${excel_reference}    Set Variable    ${excel_record}[RefNo]
        ${matching_record}    Set Variable    ${None}
        ${unmatched_record}    Set Variable    ${None}
        Log To Console          Matching Record Value ::::${matching_record}       
        FOR    ${journal_record}    IN    @{journal_transaction_details_list}
            ${journal_credit}    Set Variable    ${journal_record}[Credit]
            ${journal_debit}    Set Variable    ${journal_record}[Debit]
            ${journal_LineId}    Set Variable    ${journal_record}[LineID]
            ${journal_date}    Set Variable    ${journal_record}[jrLineDates]
            IF      '${excel_credit}' == '${journal_credit}'
                IF      '${excel_credit}' != '0.0'
                    IF      '${excel_date}' == '${journal_date}'
                        ${matching_record}      Set Variable    ${journal_record}
                        ${trans_id}    Set Variable    ${matching_record}[TransID]
                        ${matching_dict}    Create Dictionary    TransID=${trans_id}    Debit=${excel_debit}    Credit=${excel_credit}      Details=${excel_details}           Date=${excel_date}       Reference=${excel_reference}        Line_ID=${journal_LineId}
                        Append To List    ${matching_records}    ${matching_dict}
                    END
                END
            ELSE
                IF      '${excel_debit}' != '0.0'
                    IF      '${excel_details}' == 'Bank Charge'
                        ${unmatched_record}      Set Variable    ${excel_record}
                        ${un_trans_id}    Set Variable    ${unmatched_record}[TransID]
                        ${unmatching_dict}    Create Dictionary    TransID=${un_trans_id}    Debit=${excel_debit}    Credit=${excel_credit}    Details=${excel_details}     Date=${excel_date}      Reference=${excel_reference}
                        Append To List    ${unmatched_records}    ${unmatching_dict}
                    END
                END
            END
        END
    END
    ${New_Unmatched_List}   Create List
    ${lenMatched}   Evaluate    len(${matching_records})
    Log To Console    \nMatching Records: ${matching_records}       #Matchig record List
    Log To Console    Matching Records Lenghth: ${lenMatched}
    ${lenUnMatched}   Evaluate    len(${unmatched_records})
    Log To Console    \nUnMatching Records: ${unmatched_records}
    

    FOR    ${indexUnmatch}    IN RANGE    0    ${lenUnMatched}    3
        ${New_unmatched}    Set Variable    ${unmatched_records[${indexUnmatch}]}
        Append To List    ${New_Unmatched_List}    ${New_unmatched}
    END
    Log To Console      \nNew Unmatched Record: ${New_Unmatched_List}      #Unmatched recrod List
    ${New_Unmatched_Len}   Evaluate    len(${New_Unmatched_List})
    Log To Console    \nUnMatching Records: ${New_Unmatched_Len}





    #####--- POST to Get The Reconciliation List --- #####
    ${matched_Ids_Un_rec}  Create List
    IF      ${lenMatched} > 0
        ${recon_post}    Set Variable         {"ExternalReconciliationFilterParams": {"AccountCodeFrom": "${rev_bank}","AccountCodeTo": "${rev_bank}","ReconciliationAccountType": "rat_GLAccount"}}
        ${reconcile_get_response}    Post Request   ${sessionname}    ${base_url}/ExternalReconciliationsService_GetReconciliationList  data=${recon_post}  headers=${headers}
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
            ${rec_data_body}    Set Variable    {"ExternalReconciliationParams": {"AccountCode": "${rev_bank}","ReconciliationNo": ${recNum}}} 
            ${rec_data_body_get_response}    Post Request   ${sessionname}    ${base_url}/ExternalReconciliationsService_GetReconciliation  data=${rec_data_body}  headers=${headers}
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
    Log To Console  \nJournalEntry Get Lenth\t: ${unRec_TransIdlenth}
    ${LineIdsMatchedList}     Create List
    ${CreditMatchedList}     Create List
    ${DebitMatchedList}     Create List
    ${DetailsMatchedList}     Create List
    ${DatesMatchedList}     Create List
    ${referenceMatchedList}     Create List

    ################# Matched
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

    FOR     ${CreditsunMatched}    IN      @{New_Unmatched_List} 
        ${credun}     Set Variable    ${CreditsunMatched['Credit']}
        Append To List      ${Credits_UnMatchedList}     ${credun}
    END

    #===========================Debits

    FOR     ${DebitstsUnMatched}    IN      @{New_Unmatched_List} 
        ${debr}     Set Variable    ${DebitstsUnMatched['Debit']}
        Append To List      ${Debits_UnMatchedList}     ${debr}
    END    

    #===========================Details

    FOR     ${DetailsUnMatched}    IN      @{New_Unmatched_List} 
        ${detailsun}     Set Variable    ${DetailsUnMatched['Details']}
        Append To List      ${Details_UnMatchedList}     ${detailsun}
    END

    #===========================Dates

    FOR     ${DatesUnMatched}    IN      @{New_Unmatched_List} 
        ${dateun}     Set Variable    ${DatesUnMatched['Date']}
        Append To List      ${Dates_UnMatchedList}      ${dateun}
    END

    #===========================RefNos

    FOR     ${RefsUnMatched}    IN      @{New_Unmatched_List} 
        ${refun}     Set Variable    ${RefsUnMatched['Reference']}
        Append To List      ${reference_UnMatchedList}     ${refun}
    END


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
    ${DebitSum}     Evaluate    sum(${Debits_UnMatchedList})
    Log To Console      \nSum::::::::::${DebitSum}

    ###############----------BankPage POST----------###############

    ${total_recs_toReconcile}       Set Variable        ${unRec_TransIdlenth+${New_Unmatched_Len}}
    Log To Console      \nTotal Records To Reconcile: ${total_recs_toReconcile}
    IF  ${total_recs_toReconcile}>0
        FOR     ${counter}  IN RANGE    0   ${total_recs_toReconcile}
            IF      ${unRec_TransIdlenth}>0
                IF  ${counter} < ${unRec_TransIdlenth}
                    IF    '${DebitMatchedList}[${counter}]' == '0.0'
                        ${Ref_No}    Set Variable    ${referenceMatchedList}[${counter}]
                        IF      '${Ref_No}' == '0'
                            ${Ref_No}   Set Variable    null
                        ELSE
                            ${Ref_No}   Set Variable    ${Ref_No}
                        END
                        ${payload1}     Set variable        {"AccountCode": "${rev_bank}", "CreditAmount": "${CreditMatchedList}[${counter}]", "DocNumberType": "bpdt_DocNum", "Reference": ${Ref_No},"Memo":"${DetailsMatchedList}[${counter}]","DueDate":"${DatesMatchedList}[${counter}]"} 
                        Log To Console      Bank Page Post Body1:${payload1}
                        # ${response}=  Post Request  ${sessionname}    ${base_url}/BankPages  data=${payload1}  headers=${headers}
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
                    IF    '${Credits_UnMatchedList}[${counter}]' == '0.0'
                        ${Ref_No}    Set Variable    ${reference_UnMatchedList}[${counter}]
                        IF      '${Ref_No}' == '0'
                            ${Ref_No}   Set Variable    null
                        ELSE
                            ${Ref_No}   Set Variable    ${Ref_No}
                        END
                        ${payload1}     Set variable        {"AccountCode": "${rev_bank}", "DebitAmount": "${Debits_UnMatchedList}[${counter}]", "DocNumberType": "bpdt_DocNum", "Reference": ${Ref_No},"Memo":"${Details_UnMatchedList}[${counter}]","DueDate":"${Dates_UnMatchedList}[${counter}]"} 
                        Log To Console      Bank Page Post Body1:${payload1}
                        # ${response}=  Post Request  ${sessionname}    ${base_url}/BankPages  data=${payload1}  headers=${headers}
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
        Log To Console      \nNothing To reconsile........
    END
    Log To Console      \nSequence List From BankPage : ${sequencelist}
    ${bnk_page_seq_lenth}   Evaluate    len(${sequencelist})
    Log To Console      \nSequence List From BankPage Length : ${bnk_page_seq_lenth}
    Log To Console      \nUnMatched Length: ${New_Unmatched_Len}
    
    ###############----------POST & GET Journal Entry Lines----------###############
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
    #         Log To Console    \nFailjournalentry
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


    # ##############----------POST External Reconciliation----------###############

    # IF      ${bnk_page_seq_lenth} > 0
    #     #######====================================
    #     Log To Console      \nSequenceList: ${sequencelist}
    #     ${reconciliation_lines}    Create List
    #     ${bnkstmnt_lines}    Create List
    #     FOR     ${count}    IN RANGE    0   ${bnk_page_seq_lenth}
    #         ${bnkstmnt_line}    Create Dictionary    BankStatementAccountCode=${rev_bank}    Sequence=${sequencelist}[${count}]     #Ok
    #         Append To List    ${bnkstmnt_lines}    ${bnkstmnt_line}
    #         Log to Console    \n\nbnkstmnt_line: ${bnkstmnt_line}
    #     END

    #     FOR     ${TrCount}      IN RANGE    0     ${unRec_TransIdlenth }
    #         # matched_Ids_Un_rec
    #         ${reconciliation_line}    Create Dictionary    LineNumber=${LineIdsMatchedList}[${TrCount}]    TransactionNumber=${matched_Ids_Un_rec}[${TrCount}]
    #         Append To List    ${reconciliation_lines}    ${reconciliation_line}
    #         Log to Console    \n\nReconciliation_line: ${reconciliation_line}
    #     END
    #     IF      ${JdtNumbsListLength} == 1
    #         ${reconciliation_line}    Create Dictionary    LineNumber=0    TransactionNumber=${JdtNumbsList}[0]
    #         Append To List    ${reconciliation_lines}    ${reconciliation_line}
    #         Log to Console    \n\nReconciliation_line: ${reconciliation_line}
    #     END

    #     ${reconciliation_journal_entry_lines}    Evaluate    json.dumps(${reconciliation_lines})
    #     ${reconciliation_bank_statement_lines}    Evaluate    json.dumps(${bnkstmnt_lines})

    #     ${reconciliation_journal_entry_lines}    Set Variable    ${reconciliation_journal_entry_lines.replace('"[', '[').replace(']"', ']')}
    #     ${reconciliation_bank_statement_lines}    Set Variable    ${reconciliation_bank_statement_lines.replace('"[', '[').replace(']"', ']')}

    #     ${reconciliation_journal_entry_lines}    Set Variable    ${reconciliation_journal_entry_lines.replace('"\\[', '[').replace('\\]"', ']')}
    #     ${reconciliation_bank_statement_lines}    Set Variable    ${reconciliation_bank_statement_lines.replace('"\\[', '[').replace('\\]"', ']')}

    #     ${payload3}    Create Dictionary        ReconciliationAccountType=${datatype}    ReconciliationBankStatementLines=${reconciliation_bank_statement_lines}    ReconciliationJournalEntryLines=${reconciliation_journal_entry_lines}
    #     ${final_payload}    Create Dictionary    ExternalReconciliation=${payload3}

    #     ${final_payload_string}    Evaluate    json.dumps(${final_payload})

    #     ${final_payload_string}    Set Variable    ${final_payload_string.replace('\\', '')}
    #     ${final_payload_string}    Set Variable    ${final_payload_string.replace('"[', '[').replace(']"', ']')}

    #     ${final_payload_string}    Set Variable    ${final_payload_string.replace('"\\[', '[').replace('\\]"', ']')}

    #     Log To Console  \nFinal Body ExterNal ReconciliationService:\n ${final_payload_string}

    #     ${responseFinal}=  Post Request  ${sessionname}    ${base_url}/ExternalReconciliationsService_Reconcile  data=${final_payload_string}  headers=${headers}
    #     IF    ${responseFinal.status_code} == 204
    #         Log To Console      \nSuccess All
    #         Open Workbook    ${url}
    #         Set Active Worksheet    Sheet1
    #         Set Styles    G6:G9
    #         ...  color=ffffff
    #         ...  align_horizontal=center
    #         ...  align_vertical=center
    #         ...  bold=True
    #         ...  cell_fill=198754
    #         Set Cell Value  7   7     ${success_msg}
    #         Save Workbook
    #         Log To Console    \nReconciliation Success 
    #     ELSE
    #         ${ErrorMsg}     Set Variable    ${response.json()['error']['message']['value']}
    #         Open Workbook    ${url}
    #         Set Active Worksheet    Sheet1
    #         Set Styles    G6:G9
    #         ...  color=ffffff
    #         ...  align_horizontal=center
    #         ...  align_vertical=center
    #         ...  bold=True
    #         ...  cell_fill=DC143C
    #         Set Cell Value  6   7     ${fail_msg}
    #         Set Cell Value  7   7     Value: ${ErrorMsg}
    #         Set Cell Format    7   7
    #         ...   wrap_text=True
    #         Save Workbook
    #         Log To Console      Reconciliation Failed
    #     END
    # END







    




























# /////////////////////////////////////////////////
        # # getting banktransaction details
        # ${DebitAmount1list}=    Create List
        # ${CreditAmount1list}=    Create List
        # ${DueDate1list}=    Create List
        # ${Memo1list}=    Create List
        # Log To Console      List Length: ${list_length}  -1
        # FOR    ${counter}    IN RANGE    0    ${list_length}-1
        #     ${customer_response1}    Get Request    ${sessionname}    ${base_url}/BankPages?$select=AccountCode,PaymentReference,DueDate,CreditAmount,DebitAmount,Sequence,AccountName&$filter=AccountCode eq '${coded}' and CreditAmount eq ${Excel_Creditlist}[${counter}] and DebitAmount eq ${Excel_Debitlist}[${counter}] and DueDate eq '${Transdatelist}[${counter}]'&$orderby=Sequence desc 
        #         IF  ${customer_response1.status_code} == 200
        #             Log To Console    Response Val json: ${customer_response1.json()}
                    # Log To Console    Response Val json: ${customer_response1.json()['value'][0]}
    #                 ${customer_data1}    Set Variable    ${customer_response1.json()['value'][0]}
    #                 ${AccountCode}    Set Variable    ${customer_data1['AccountCode']}
    #                 ${Sequence}    Set Variable    ${customer_data1['Sequence']}
    #                 Log to Console      Sequencseeeeeeee: ${Sequence}
    #                 ${AccountName}    Set Variable    ${customer_data1['AccountName']}   
    #                 ${DueDate1}    Set Variable    ${customer_data1['DueDate']}   
    #                 ${DueDate1}    Convert Date    ${customer_data1['DueDate']}    result_format=%d%m%Y 
    #                 ${DueDate1}    Convert To Number    ${DueDate1}
    #                 ${Memo1}    Set Variable    ${customer_data1['PaymentReference']}
    #                 ${DebitAmount1}    Set Variable    ${customer_data1['DebitAmount']}
    #                 ${DebitAmount1}    Convert To Integer    ${DebitAmount1}
    #                 ${CreditAmount1}    Set Variable    ${customer_data1['CreditAmount']}
    #                 ${CreditAmount1}    Convert To Integer    ${CreditAmount1}  
    #                 Append To List    ${sequencelist}    ${Sequence}
    #                 Append To List    ${DebitAmount1list}    ${DebitAmount1}
    #                 Append To List    ${CreditAmount1list}    ${CreditAmount1}
    #                 Append To List    ${DueDate1list}    ${DueDate1}
    #                 Append To List    ${Memo1list}    ${Memo1}   
        #         # ELSE
        #             Log To Console      Failed get bankpages\n
        #             Log To Console    Response Val json: ${customer_response1.json()}\n  
        #         END
        # END
    #     # getting journal entries
    #     FOR    ${counter}    IN RANGE    0    ${list_length}
    #                 IF    ${TransIDlist}[${counter}] == 0   
    #                     IF    ${Excel_Creditlist}[${counter}] == 0
    #                         ${PAYLOAD2}    Set Variable         {"JournalEntryLines": [{"AccountCode": "${bank1}","Credit": ${Excel_Debitlist}[${counter}],"Debit": ${Excel_Creditlist}[${counter}],"BPLID": 1},{"AccountCode": "${bank}","Credit": ${Excel_Creditlist}[${counter}],"Debit": ${Excel_Debitlist}[${counter}],"BPLID": 1}]}
    #                     ELSE
    #                         ${PAYLOAD2}    Set Variable         {"JournalEntryLines": [{"AccountCode": "${bank}","Credit": ${Excel_Creditlist}[${counter}],"Debit": ${Excel_Debitlist}[${counter}],"BPLID": 1},{"AccountCode": "${bank1}","Credit": ${Excel_Debitlist}[${counter}],"Debit": ${Excel_Creditlist}[${counter}],"BPLID": 1}]}
    #                     END
    #                     ${response}=  Post Request  ${sessionname}    ${base_url}/JournalEntries  data=${PAYLOAD2}  headers=${headers}
    #                     IF    ${response.status_code} == 201
    #                         Log To Console    successjournalentry
    #                     ELSE
    #                         Log To Console    failjournalentry
    #                     END
    #                 ELSE
    #                     ${customer_response}    Get Request    ${sessionname}    ${base_url}/JournalEntries(${TransIDlist}[${counter}])/JournalEntryLines
    #                         IF    ${customer_response.status_code} == 200
    #                             ${customer_datad}    Set Variable    ${customer_response.json()['JournalEntryLines']}
    #                             ${count}=    Set Variable    0
    #                             #getting count of journal entries lines storing count variable
    #                                 FOR    ${dict}    IN    @{customer_datad}
    #                                     ${line_id}=    Get From Dictionary    ${dict}    Line_ID
    #                                     ${count}=    Evaluate    ${count}+1    
    #                                 END
    #                                 log to console   Count: ${count}
    #                         #iterate the journal entries lines to get the match details
    #                             FOR    ${counter}    IN RANGE    0    ${count}    
    #                                         ${customer_data}    Set Variable    ${customer_response.json()['JournalEntryLines'][${counter}]}
    #                                         ${DebitAmount}    Set Variable    ${customer_data['Debit']}
    #                                         ${DebitAmount}    Convert To Integer    ${DebitAmount}
    #                                         ${CreditAmount}    Set Variable    ${customer_data['Credit']}
    #                                         ${CreditAmount}    Convert To Integer    ${CreditAmount}
    #                                         ${Line_ID}    Set Variable    ${customer_data['Line_ID']}  
    #                                         ${Referencid}    Set Variable    ${customer_data['Reference1']} 
    #                                         ${DueDatejo}    Set Variable    ${customer_data['DueDate']}
    #                                         ${DueDatejo}       Convert Date    ${DueDatejo}    result_format=%Y-%m-%dT%H:%M:%SZ
    #                                         ${Memo}    Set Variable    ${customer_data['LineMemo']}
    #                                         FOR    ${counter1}    IN RANGE    0    ${list_length}-1    
    #                                             ${memo1}    Run Keyword And Ignore Error    Should Be Equal As Strings    ${Memo}    ${Detailslist}[${counter1}]
    #                                         ${memo1}    Set Variable    ${memo1}[0]
    #                                         ${pass}    Set Variable    PASS
    #                                         # Log To Console      \n${CreditAmount1list}[${counter1}] == ${CreditAmount} \nand "${customer_data['LineMemo']}" == "${Detailslist}[${counter1}]" \nand ${DebitAmount1list}[${counter1}] == ${DebitAmount} \nand ${Referencid} == ${Refnolist}[${counter1}]
    #                                         ${condition}=    Evaluate    "${customer_data['LineMemo']}" == "${Detailslist}[${counter1}]" and ${Referencid} == ${Refnolist}[${counter1}]
    #                                         Run Keyword If    ${condition}    Append To List    ${linidlist}    ${Line_ID}    
    #                                         #   Run Keyword And Ignore Error    ${CreditAmount1list}[${counter1}] == ${CreditAmount} and ${memo1} == ${pass} and ${DebitAmount1list}[${counter1}] == ${DebitAmount} 
    #                                         #    Append To List    ${linidlist}    ${Line_ID}  
    #                                         END
    #                                     END
    #                             ELSE
    #                                 Log To Console     fail
    #                             END
    #                 END
    #     END
    #     Log To Console      \nLineIdLists: ${linidlist}\n
    #     log to console      \nSequenceLists: ${sequencelist}\n
    #     ${sequencelist}    Remove Duplicates    ${sequencelist}
    #     #  ${linidlist}    Remove Duplicates    ${linidlist}
    #     ${TransIDlist}    Remove Duplicates    ${TransIDlist}
    #     ${linidlist_length}=    Get Length    ${linidlist}
    #     IF    ${linidlist_length} == 0
    #         Log To Console      "There are no transaction with these details Or Already Reconciled..."
    #     ELSE
    #         Log To Console      \nLineIdList: ${linidlist}\nTransId: ${TransIDlist}\nAccountCode: ${coded}\nSequenceList:${sequencelist}\n
    #     # posting external reconciliation
    #     posting ExternalReconciliation    ${linidlist}    ${TransIDlist}    ${coded}    ${sequencelist}  ${headers}     
    # END
# posting ExternalReconciliation 
#     [Arguments]    ${linidlist}    ${TransIDlist}    ${coded}    ${sequencelist}    ${headers}  
#     Log To Console      Line Id1: ${linidlist}[0],Line Id2:${linidlist}[1]
#     IF      ${linidlist}
#         ${payload3}    Set Variable  {"ExternalReconciliation": {"ReconciliationAccountType": "${datatype}","ReconciliationBankStatementLines":[ {"BankStatementAccountCode": "${coded}","Sequence": ${sequencelist}[0]},{"BankStatementAccountCode": "${coded}","Sequence": ${sequencelist}[1]}],"ReconciliationJournalEntryLines":[{"LineNumber": ${linidlist}[0],"TransactionNumber": ${TransIDlist}[0]},{"LineNumber": ${linidlist}[1],"TransactionNumber": ${TransIDlist}[1]}]}}          
#         ${response}=  Post Request  ${sessionname}    ${base_url}/ExternalReconciliationsService_Reconcile  data=${payload3}  headers=${headers}
#         IF    ${response.status_code} == 204
#             Open Workbook    ${url}
#             Set Active Worksheet    Sheet1
#             Set Styles    G3:G5
#             ...  color=ffffff
#             ...  align_horizontal=center
#             ...  align_vertical=center
#             ...  bold=True
#             ...  cell_fill=198754
#             Set Cell Value  4   7     ${success_msg}
#             Save Workbook
#             Log To Console    Reconciliation Success 
#         ELSE
#             ${ErrorMsg}     Set Variable    ${response.json()['error']['message']['value']}
#             # Log To Console      \nMsg: ${ErrorMsg}\n
#             Open Workbook    ${url}
#             Set Active Worksheet    Sheet1
#             Set Styles    G3:G5
#             ...  color=ffffff
#             ...  align_horizontal=center
#             ...  align_vertical=center
#             ...  bold=True
#             ...  cell_fill=DC143C
#             # ...  wrap_text=True
#             Set Cell Value  4   7     ${fail_msg}
#             Set Cell Value  5   7     Value: ${ErrorMsg}
#             Set Cell Format    5   7
#             ...   wrap_text=True
#             Save Workbook
#             Log To Console      Reconciliation Failed
#         END
#     END



