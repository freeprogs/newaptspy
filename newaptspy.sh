#!/bin/bash

# This script searches and loads cheap drugs on site https://newapteka.ru
# for city Yuzhno-Sakhalinsk in a multi-line or one-line mode.
# Copyright (C) 2022, Slava <freeprogs.feedback@yandex.ru>
# License: GNU GPLv3

progname=`basename $0`

# Print an error message to stderr
# error(str)
error()
{
    echo "error: $progname: $1" >&2
}

# Print a message to stdout
# msg(str)
msg()
{
    echo "$progname: $1"
}

# Print program usage to stderr
# usage()
usage()
{
    echo "Try \`$progname --help' for more information." >&2
}

# Print program help info to stderr
# help_info()
help_info()
{
    {
        echo "usage: $progname [--oneline] drugname"
        echo ""
        echo "Searches and loads cheap drugs on site https://newapteka.ru for city"
        echo "Yuzhno-Sakhalinsk in a multi-line (default) or one-line mode."
        echo ""
        echo "  noarg      --  Print program usage information."
        echo "  --help     --  Print program help information."
        echo "  --version  --  Print program version information."
        echo "  --oneline  --  Switch on the one-line mode."
        echo ""
    } >&2
}

# Print program version information to stderr
# print_version()
print_version()
{
    {
        echo "newaptspy v1.0.0"
        echo "Copyright (C) 2022, Slava <freeprogs.feedback@yandex.ru>"
        echo "License: GNU GPLv3"
    } >&2
}

# Search for a drug by the search pattern and print result in
# multi-line mode
# search_drug_multiline(drug_pattern)
# args:
#   drug_pattern - A search pattern for a drug
# stdout:
#   Sequence of multi-line formatted records
search_drug_multiline()
{
    local drug_pattern=$1
    local city_id=4
    local swd
    local swd_filtered
    local swd_f_sorted
    local out

    swd=`join_drugstores_with_drugs "$city_id" "$drug_pattern"`
    if [ -n "$swd" ]; then
        swd_filtered=`echo "$swd" | filter_remove_empty_price`
        swd_f_sorted=`echo "$swd_filtered" | sorter_sort_by_price`
        out=`echo "$swd_f_sorted" | wrapper_wrap_store_drug_multiline`
    else
        out="Nothing found."
    fi
    echo "$out"
}

# Search for a drug by the search pattern and print result in
# one-line mode
# search_drug_oneline(drug_pattern)
# args:
#   drug_pattern - A search pattern for a drug
# stdout:
#   Sequence of one-line formatted records
search_drug_oneline()
{
    local drug_pattern=$1
    local city_id=4
    local swd
    local swd_filtered
    local swd_f_sorted
    local out

    swd=`join_drugstores_with_drugs "$city_id" "$drug_pattern"`
    if [ -n "$swd" ]; then
        swd_filtered=`echo "$swd" | filter_remove_empty_price`
        swd_f_sorted=`echo "$swd_filtered" | sorter_sort_by_price`
        out=`echo "$swd_f_sorted" | wrapper_wrap_store_drug_oneline`
    else
        out="Nothing found."
    fi
    echo "$out"
}

# Filter only records with a filled price field
# filter_remove_empty_price()
# stdin:
#   Sequence of raw records
# stdout:
#   Sequence of raw records without records
#   containing an empty price field
filter_remove_empty_price()
{
    awk -F ';' '$6 {print}'
}

# Sort records by the price field
# sorter_sort_by_price()
# stdin:
#   Sequence of raw records
# stdout:
#   Sequence of raw records sorted by the price field
#   in ascending order
sorter_sort_by_price()
{
    python3 -c '
import sys

gen = (i.split(";") for i in sys.stdin)
lst = sorted(gen, key=lambda i: float(i[5]))
for i in lst:
    out = ";".join(i)
    print(out, end="")
'
}

# Wrap raw records to a formatted multi-line records
# wrapper_wrap_store_drug_multiline()
# stdin:
#   Sequence of raw records
# stdout:
#   Sequence of formatted multi-line records
wrapper_wrap_store_drug_multiline()
{
    awk -F ';' '
{
    print "#" ++n " Аптека", $1
    print "Время работы", $2
    print "  " $3
    print "  Производитель", $4, $5
    print "  " $6, ($7) ? "по скидке " $7 : "без скидки"
}
'
}

# Wrap raw records to a formatted one-line records
# wrapper_wrap_store_drug_oneline()
# stdin:
#   Sequence of raw records
# stdout:
#   Sequence of formatted one-line records
wrapper_wrap_store_drug_oneline()
{
    awk -F ';' '
{
    print "#" ++n " Аптека",
           $1,
           "|",
           "Время работы",
           $2,
           "|",
           $3,
           "|",
           "Производитель",
           $4,
           $5,
           "|",
           "Цена",
           $6,
           ($7) ? "по скидке " $7 : "без скидки"
}
'
}

# Join drugstores with found drugs in these drugstores and make raw
# records for these joins
# join_drugstores_with_drugs(city_id, drug_pattern)
# args:
#   city_id - City identificator for search
#   drug_pattern - A drug pattern for search
# stdout:
#   Sequence of raw records in form
#   address;worktime;drugname;county;maker;price;discount
# return:
#   0 - If success
#   1 - If any error
join_drugstores_with_drugs()
{
    local city_id=$1
    local drug_pattern=$2
    local record
    local drugstore_id
    local drugstore_address
    local drugstore_worktime
    local IFS_old

    IFS_old="$IFS"
    IFS=$'\n'
    for drugstore_record in $(city_get_drugstores_list "$city_id"); do
        drugstore_id=`drugstorehand_get_id "$drugstore_record"`
        drugstore_address=`drugstorehand_get_address "$drugstore_record"`
        drugstore_worktime=`drugstorehand_get_worktime "$drugstore_record"`
        for drug_record in $(drugstorehand_search_drug "$drugstore_id" "$drug_pattern"); do
            drug_name=`drughand_get_name "$drug_record"`
            drug_country=`drughand_get_country "$drug_record"`
            drug_maker=`drughand_get_maker "$drug_record"`
            drug_price=`drughand_get_price "$drug_record"`
            drug_price_discount=`drughand_get_price_discount "$drug_record"`
            echo \
"${drugstore_address};"\
"${drugstore_worktime};"\
"${drug_name};"\
"${drug_country};"\
"${drug_maker};"\
"${drug_price};"\
"${drug_price_discount}"
        done
    done
    IFS="$IFS_old"

    return 0
}

# Load drugstores list for the given city identificator
# city_get_drugstores_list(city_id)
# args:
#   city_id - City identificator for load its drugstores
# stdout:
#   Sequence of raw drugstore records in form
#   drugstore_id;drugstore_address;drugstore_worktime_breaktime
# return:
#   0 - If success
#   1 - If any error
city_get_drugstores_list()
{
    local city_id=$1
    local url

    url="https://api.newapteka.ru/Proc/TradePointGet?"\
"idCity=${city_id}&returnType=all&ApiVersion=3"

    curl -s "$url" | python3 -c '
import sys
import json

doc = json.load(sys.stdin)
drugstore_list = doc["Data"]
for item in drugstore_list:
    drugstore_id = item["idRecord"]
    address = item["AddressDostFull"]
    work_time = item["wtToday"]
    work_break = item["wtBreakToday"]
    fmt = "{};{};{} {}"
    print(fmt.format(drugstore_id, address, work_time, work_break))
'
}

# Get id field from the raw drugstore record
# drugstorehand_get_id(drugstore_record)
# args:
#   drugstore_record - A raw drugstore record
# stdout:
#   The id field value in the record
drugstorehand_get_id()
{
    echo "$1" | awk -F ';' '{print $1}'
}

# Get address field from the raw drugstore record
# drugstorehand_get_address(drugstore_record)
# args:
#   drugstore_record - A raw drugstore record
# stdout:
#   The address field value in the record
drugstorehand_get_address()
{
    echo "$1" | awk -F ';' '{print $2}'
}

# Get worktime field from the raw drugstore record
# drugstorehand_get_worktime(drugstore_record)
# args:
#   drugstore_record - A raw drugstore record
# stdout:
#   The worktime field value in the record
drugstorehand_get_worktime()
{
    echo "$1" | awk -F ';' '{print $3}'
}

# Search and load drugs by name pattern from the given drugstore
# drugstorehand_search_drug(drugstore_id, drag_pattern)
# args:
#   drugstore_id - Drugstore identificator for search
#   drug_pattern - A drug pattern for search
# stdout:
#   Sequence of raw drug records in form
#   drugname;country;maker;price;discount
# return:
#   0 - If success
#   1 - If any error
drugstorehand_search_drug()
{
    local drugstore_id=$1
    local drugname=$2
    local url

    url="https://api.newapteka.ru/search/main?"\
"idTradePoint=${drugstore_id}&Request=${drugname}"\
"&SearchType=2&ReturnType=&Sorting=5&idGroup=&Page=1"\
"&PerPage=1&idAdvDiscountPage=&dontUseMix=0&idReplacement=&"\
"idMNN=&LongSessionID=&ApiVersion=3"

    curl -s "$url" | python3 -c '
import sys
import json

doc = json.load(sys.stdin)
drugs_list = doc["Data"]["tovar"]
for item in drugs_list:
    drugname = item["LongTovarName"]
    country = item["NameCountry"]
    maker = item["NameMaker"]
    if item["PriceWoDiscount"] is not None:
        price = item["PriceWoDiscount"]
    else:
        price = ""
    if item["Price"] is not None:
        price_discount = item["Price"]
    else:
        price_discount = ""
    fmt = "{};{};{};{};{}"
    print(fmt.format(drugname, country, maker, price, price_discount))
'
}

# Get drugname field from the raw drug record
# drughand_get_name(drug_record)
# args:
#   drug_record - A raw drug record
# stdout:
#   The drugname field value in the record
drughand_get_name()
{
    echo "$1" | awk -F ';' '{print $1}'
}

# Get country field from the raw drug record
# drughand_get_country(drug_record)
# args:
#   drug_record - A raw drug record
# stdout:
#   The country field value in the record
drughand_get_country()
{
    echo "$1" | awk -F ';' '{print $2}'
}

# Get maker field from the raw drug record
# drughand_get_maker(drug_record)
# args:
#   drug_record - A raw drug record
# stdout:
#   The maker field value in the record
drughand_get_maker()
{
    echo "$1" | awk -F ';' '{print $3}'
}

# Get price field from the raw drug record
# drughand_get_price(drug_record)
# args:
#   drug_record - A raw drug record
# stdout:
#   The price field value in the record
drughand_get_price()
{
    echo "$1" | awk -F ';' '{print $4}'
}

# Get discount field from the raw drug record
# drughand_get_price_discount(drug_record)
# args:
#   drug_record - A raw drug record
# stdout:
#   The discount field value in the record
drughand_get_price_discount()
{
    echo "$1" | awk -F ';' '{print $5}'
}

# Search and load cheap drugs on site https://newapteka.ru for city
# Yuzhno-Sakhalinsk in a multi-line or one-line mode
# main([[--oneline] drug_pattern])
# args:
#   drug_pattern - A search pattern for a drug
# return:
#   0 - If drugs loaded
#   1 - If any error
main()
{
    local drugname

    case $# in
      0)
        usage
        return 1
        ;;
      1)
        [ "$1" = "--help" ] && {
            help_info
            return 1
        }
        [ "$1" = "--version" ] && {
            print_version
            return 1
        }
        usage
        drugname=$1
        search_drug_multiline "$drugname" || return 1
        ;;
      2)
        [ "$1" = "--oneline" ] || return 1
        usage
        drugname=$2
        search_drug_oneline "$drugname" || return 1
        ;;
      *)
        error "unknown arglist: $*"
        return 1
        ;;
    esac
}

main "$@" || exit 1

exit 0
